# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "active_support"
require "active_support/cache"

###
# The merge protocol has to behave identically on a cache store and on Redis,
# so the suite is written once and run against both.
#
# Everything here is about what happens when two processes report at the same
# time, when one of them dies holding unconfirmed work, or when the backend
# quietly drops what we wrote.
###
module ProtocolConformance
  def build_session(key_base: "conformance.test", **opts)
    Coverband::Storage::Session.new(
      target: target,
      key_base: key_base,
      merger: counter_merger,
      **opts
    )
  end

  # apply a session's pending prefix to a document it read earlier, the way a
  # real report would, so an interleaving can be set up deterministically
  def write_as(session, doc)
    writer = session.instance_variable_get(:@writer)
    prefix = writer.contiguous_prefix(doc.watermark_for(writer.writer_id))
    session.send(:apply, doc, prefix)
    doc.record_watermark(writer.writer_id, prefix.last.seq)
    session.send(:operation) { session.send(:write, doc) }
  end

  # a deliberately non-idempotent merge: applying the same delta twice inflates
  # the total, which is what the applied sequence guard has to prevent
  def counter_merger
    lambda do |doc, delta|
      delta.payload.each do |key, value|
        next if doc.tombstoned?(key, delta.tombstone_epoch)

        doc.payload[key.to_s] = doc.payload[key.to_s].to_i + value.to_i
      end
    end
  end

  def test_single_writer_totals_are_exact
    session = build_session
    session.record({"a" => 1})
    session.record({"a" => 2})
    assert_equal 3, session.entries["a"]
  end

  ###
  # Re-flushing must be a no-op. Without the watermark this is where additive
  # merges would silently inflate.
  ###
  def test_reflush_does_not_double_count
    session = build_session
    session.record({"a" => 5})
    5.times { session.flush }
    assert_equal 5, session.entries["a"]
  end

  ###
  # Two writers, one stale write. The loser's contribution and its watermark
  # both disappear, which is precisely what lets it notice and repair.
  ###
  def test_two_writers_converge_after_a_stale_write
    a = build_session
    b = build_session
    a.entries
    b.entries # both learn the generation and read the same empty document

    a.enqueue({"hits" => 1})
    b.enqueue({"hits" => 10})
    doc_a = a.send(:operation) { a.send(:document) }
    doc_b = b.send(:operation) { b.send(:document) }

    write_as(a, doc_a)
    write_as(b, doc_b) # stale: built from the document as it was before a wrote

    # b's write dropped a's contribution along with a's watermark
    assert_equal 10, a.entries["hits"]

    # settle
    3.times do
      a.flush
      b.flush
    end
    assert_equal 11, a.entries["hits"], "both contributions should survive exactly once"
  end

  ###
  # A watermark may never record a sequence whose predecessor isn't in the
  # payload, or the gap would be confirmed away and lost for good.
  ###
  def test_watermark_never_skips_a_gap
    session = build_session
    writer = session.instance_variable_get(:@writer)
    session.enqueue({"a" => 1})
    session.enqueue({"a" => 2})

    # only seq 2 is present locally: seq 1 was already handed off
    prefix = writer.contiguous_prefix(0)
    assert_equal [1, 2], prefix.map(&:seq)

    writer.instance_variable_get(:@pending).reject! { |d| d.seq == 1 }
    assert_empty writer.contiguous_prefix(0), "a gap must stop the prefix"
    assert_equal [2], writer.contiguous_prefix(1).map(&:seq)
  end

  def test_deltas_are_frozen_after_enqueue
    session = build_session
    delta = session.enqueue({"a" => 1})
    assert delta.frozen?
    assert delta.payload.frozen?
  end

  ###
  # Pids get reused. A new process inheriting one must not inherit the dead
  # writer's high watermark, or its own low sequences look already applied.
  ###
  def test_writer_identity_is_not_derived_from_pid
    one = Coverband::Storage::Writer.new(max_entries: 5, max_bytes: 1000, max_age: 60)
    two = Coverband::Storage::Writer.new(max_entries: 5, max_bytes: 1000, max_age: 60)
    refute_equal one.writer_id, two.writer_id
  end

  ###
  # A forked child must not re-apply what the parent already applied under the
  # parent's identity.
  ###
  def test_fork_resets_identity_and_drops_inherited_pending
    writer = Coverband::Storage::Writer.new(max_entries: 5, max_bytes: 1000, max_age: 60)
    writer.enqueue({"a" => 1}, tombstone_epoch: 0)
    original_id = writer.writer_id
    assert_equal 1, writer.pending_size

    # a fork lands the child in a process whose pid isn't the one it recorded
    writer.instance_variable_set(:@pid, -1)

    refute_equal original_id, writer.writer_id
    assert_equal 0, writer.pending_size, "inherited pending would double count"
  end

  def test_pending_dropped_by_age_records_data_loss
    session = build_session(max_age: -1)
    session.enqueue({"a" => 1})
    session.flush
    refute_nil session.data_loss
    assert_equal :pending_dropped, session.data_loss.kind
  end

  ###
  # A reset retires the whole generation, so a writer still holding the old
  # token writes somewhere nothing reads.
  ###
  def test_reset_is_not_undone_by_a_stale_writer
    a = build_session
    b = build_session
    a.record({"a" => 1})
    b.entries # b learns the current token
    retired_key = b.send(:data_key)

    assert a.reset, "reset should report success"

    # a write that was already in flight when the reset happened lands on the
    # retired key, which nothing reads any more
    target.write(retired_key, {"meta" => {}, "payload" => {"a" => 99}}.to_json)

    assert_equal({}, a.entries, "the reset must stand")
  end

  def test_reset_reports_failure_when_the_pointer_write_fails
    session = build_session
    session.record({"a" => 1})
    target.stubs(:write).returns(false)
    refute session.reset, "a reset that isn't durable must not report success"
  end

  def test_concurrent_resets_collapse_to_one_generation
    a = build_session
    b = build_session
    a.record({"a" => 1})
    b.entries

    assert a.reset
    assert b.reset
    assert_equal({}, a.entries)
    assert_equal a.generation_token, b.generation_token
  end

  ###
  # No wall clock anywhere: a writer has to have observed the tombstone before
  # it can put the key back.
  ###
  def test_tombstone_blocks_a_writer_that_never_saw_the_delete
    a = build_session
    b = build_session
    a.record({"gone" => 1})

    b.entries # b observes epoch 0
    b.enqueue({"gone" => 5}) # stamped with the pre-delete epoch

    a.delete_entry("gone")
    assert_nil a.entries["gone"]

    b.flush
    assert_nil a.entries["gone"], "a stale delta must not resurrect a deleted key"
  end

  def test_tombstoned_key_can_be_recorded_again_once_observed
    a = build_session
    b = build_session
    a.record({"gone" => 1})
    a.delete_entry("gone")

    b.entries # observes the tombstone
    b.record({"gone" => 7})
    assert_equal 7, a.entries["gone"]
  end

  ###
  # A write that isn't durable must leave the work pending; dropping it because
  # the call returned false rather than raising is how data goes missing.
  ###
  def test_failed_write_retains_pending
    session = build_session
    session.enqueue({"a" => 1})
    target.stubs(:write).returns(false)
    assert_equal :failed, session.flush
    assert_equal 1, session.pending_size
  end

  def test_corrupt_document_degrades_and_flags_data_loss
    session = build_session
    session.record({"a" => 1})
    target.write(session.send(:data_key), "{not json")
    assert_equal({}, session.entries)
    assert_equal :corrupt_document, session.data_loss.kind
  end

  def test_reports_states_rather_than_outcomes
    session = build_session
    assert_equal :written_unconfirmed, session.record({"a" => 1})
    assert_equal :confirmed, session.flush
    assert_equal :deferred, session.flush
  end
end

class CacheProtocolConformanceTest < Minitest::Test
  include ProtocolConformance

  def setup
    super
    @cache = ActiveSupport::Cache::MemoryStore.new
    @target = Coverband::Storage::Target.new(@cache)
  end

  attr_reader :target
end

class RedisProtocolConformanceTest < Minitest::Test
  include ProtocolConformance

  def setup
    super
    @target = Coverband::Storage::RedisTarget.new(Coverband::Test.redis)
  end

  attr_reader :target
end
