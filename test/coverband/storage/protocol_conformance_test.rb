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

  ###
  # Dropping a delta at the caps leaves a hole above the watermark. If the
  # prefix will not step over it, the document stops being written on this flush
  # and every flush after it.
  ###
  def test_a_dropped_delta_does_not_stall_the_document_forever
    session = build_session(max_entries: 1)
    session.enqueue({"a" => 1})
    session.enqueue({"a" => 2})

    assert_equal :written_unconfirmed, session.flush
    assert_equal 2, session.entries["a"], "the surviving delta must still land"

    session.enqueue({"a" => 4})
    assert_equal :written_unconfirmed, session.flush
    assert_equal 6, session.entries["a"], "later work must keep landing"
  end

  def test_stepping_over_a_gap_does_not_replay_the_survivor
    session = build_session(max_entries: 1)
    session.enqueue({"a" => 1})
    session.enqueue({"a" => 2})
    session.flush
    3.times { session.flush }
    assert_equal 2, session.entries["a"], "re-flushing must not reapply"
  end

  ###
  # Losing an initialization race carries unconfirmed work forward, because the
  # orphaned generation can never become authoritative. An operator reset must
  # not be mistaken for that, or pre-reset work lands in the new generation.
  ###
  def test_reset_by_another_process_does_not_carry_work_forward
    writer = build_session
    operator = build_session

    writer.record({"a" => 1}) # written, still unconfirmed
    operator.entries # learn the generation the writer initialized

    assert operator.reset
    writer.flush # the writer only now notices the token changed

    assert_equal({}, writer.entries, "pre-reset work must not land in the new generation")
  end

  ###
  # Tombstones outlive the deltas they filter. Pruning by a count of later
  # deletes let a burst of clears drop a seconds-old tombstone while a stale
  # delta was still pending.
  ###
  def test_tombstones_are_pruned_by_age_not_by_delete_count
    a = build_session
    b = build_session
    a.record({"gone" => 1})
    b.entries
    b.enqueue({"gone" => 5}) # stamped pre-delete

    a.delete_entry("gone")
    1_100.times { |i| a.delete_entry("filler_#{i}") }

    b.flush
    assert_nil a.entries["gone"], "a burst of clears must not expose the deleted key"
  end

  ###
  # Observing someone else's delete has to move the epoch stamped on our next
  # delta, or genuine later observations are filtered out as pre-delete.
  ###
  def test_observing_a_delete_lets_the_key_be_recorded_again
    a = build_session
    b = build_session
    a.record({"key" => 1})
    b.record({"other" => 1}) # b writes, caching the epoch it saw

    a.delete_entry("key")
    b.entries # b observes the delete

    b.record({"key" => 9})
    assert_equal 9, a.entries["key"], "a post-delete observation must be accepted"
  end

  ###
  # A quiet tracker should not rewrite its whole document every cycle just to
  # confirm that nothing changed.
  ###
  def test_an_empty_report_does_not_rewrite_the_document
    session = build_session
    session.record({"a" => 1})
    session.flush # confirm

    writes = 0
    target.define_singleton_method(:write) do |key, value, options = {}|
      writes += 1
      super(key, value, options)
    end
    5.times { session.record({}) }
    assert_equal 0, writes, "quiet cycles must not rewrite the document"
  ensure
    target.singleton_class.remove_method(:write) if target.singleton_class.method_defined?(:write)
  end

  ###
  # Dropping the whole queue is the same wedge as dropping one delta: the
  # counter has to come back to the watermark or the next enqueue starts above
  # it and no prefix ever matches again.
  ###
  def test_dropping_the_entire_queue_does_not_wedge_the_writer
    writer = Coverband::Storage::Writer.new(max_entries: 5, max_bytes: 10_000, max_age: -1)
    writer.enqueue({"a" => 1}, tombstone_epoch: 0)
    assert_equal 1, writer.enforce_caps!.length
    writer.rebase_pending!(0)

    delta = writer.enqueue({"a" => 2}, tombstone_epoch: 0)
    assert_equal 1, delta.seq, "the next delta has to sit directly above the watermark"
    assert_equal [1], writer.contiguous_prefix(0).map(&:seq)
  end

  ###
  # Tombstone epochs restart at zero in a new generation, so remembering a
  # larger one from the retired generation would ignore its first deletes.
  ###
  def test_tombstone_observation_resets_with_the_generation
    a = build_session
    b = build_session
    a.record({"one" => 1})
    3.times { |i| a.delete_entry("gone_#{i}") }
    b.entries
    b.newly_tombstoned

    assert a.reset
    b.entries # b picks up the new generation

    a.record({"two" => 1})
    a.delete_entry("two")
    b.entries

    assert_includes b.newly_tombstoned, "two",
      "a delete in the new generation must not be masked by the old epoch"
  end

  ###
  # A pointer can be evicted while the document it addressed survives. That
  # orphans real data, so it is reported rather than passed off as an ordinary
  # generation change.
  ###
  def test_pointer_eviction_is_reported_as_an_orphaned_generation
    reasons = []
    session = build_session(on_generation_change: ->(reason) { reasons << reason })
    session.record({"a" => 1})

    target.delete(session.pointer_key)
    session.entries

    assert_equal :orphaned_generation, session.data_loss.kind
    assert_equal [:eviction], reasons
  end

  def test_stored_size_resolves_the_generation_first
    session = build_session
    assert_nil session.stored_size
    session.record({"a" => 1})

    fresh = build_session
    assert fresh.stored_size > 1, "a session that has not synced yet still has to find the document"
  end

  ###
  # One pointer read for the cycle rather than one per document.
  ###
  def test_pointers_can_be_prefetched_in_one_round_trip
    a = build_session(key_base: "prefetch.a")
    b = build_session(key_base: "prefetch.b")
    a.record({"x" => 1})
    b.record({"y" => 1})

    fresh_a = build_session(key_base: "prefetch.a")
    fresh_b = build_session(key_base: "prefetch.b")
    Coverband::Storage::Session.prefetch_pointers(target, [fresh_a, fresh_b])

    reads = 0
    target.define_singleton_method(:read) do |key|
      reads += 1 if key.end_with?(".pointer")
      super(key)
    end
    assert_equal 1, fresh_a.entries["x"].to_i
    assert_equal 1, fresh_b.entries["y"].to_i
    assert_equal 0, reads, "primed pointers must not be read again individually"
  ensure
    target.singleton_class.remove_method(:read) if target.singleton_class.method_defined?(:read)
  end

  ###
  # A prefetched pointer is only good for the cycle that fetched it. A session
  # that does not report in that cycle would otherwise hold it indefinitely, and
  # a reset in between would send its eventual write into a retired generation
  # where nothing can read it.
  ###
  def test_a_stale_primed_pointer_is_not_trusted
    writer = build_session
    idle = build_session
    writer.record({"a" => 1})

    # the idle session is handed the pointer, then never reports this cycle
    Coverband::Storage::Session.prefetch_pointers(target, [writer, idle])
    assert idle.instance_variable_get(:@primed_pointer), "the batch should have primed it"

    # meanwhile another process resets, and the primed value ages out
    assert writer.reset
    idle.instance_variable_set(:@primed_at, Time.now.to_i - 3600)

    idle.record({"b" => 2})
    assert_equal 2, writer.entries["b"].to_i,
      "a stale primed pointer must not send the write into a retired generation"
  end

  ###
  # Unconfirmed deltas and primed pointers are both transient cycle state held
  # between reports. A leak check has to be able to put a session back to a
  # quiet baseline, or that state looks like a leak.
  ###
  def test_discard_pending_clears_transient_cycle_state
    a = build_session
    b = build_session
    a.enqueue({"a" => 1})
    Coverband::Storage::Session.prefetch_pointers(target, [a, b])
    assert a.pending_size > 0
    refute_nil a.instance_variable_get(:@primed_pointer)

    a.discard_pending!

    assert_equal 0, a.pending_size
    assert_nil a.instance_variable_get(:@primed_pointer), "a primed pointer is cycle state too"
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
    assert_equal :retained, session.flush
    assert_equal 1, session.pending_size
  end

  ###
  # Trackers dedupe locally and forever. If an eviction does not invalidate that
  # dedupe, the keys they could still re-report stay unreported.
  ###
  def test_eviction_invalidates_local_dedupe
    reasons = []
    session = build_session(on_generation_change: ->(reason) { reasons << reason })
    session.record({"a" => 1})

    target.delete(session.send(:data_key))
    session.entries

    assert_equal :eviction, session.data_loss.kind
    assert_equal [:eviction], reasons,
      "the tracker has to be told this was an eviction, not an operator reset"
  end

  def test_corrupt_document_degrades_and_flags_data_loss
    session = build_session
    session.record({"a" => 1})
    target.write(session.send(:data_key), "{not json")
    assert_equal({}, session.entries)
    assert_equal :corrupt_document, session.data_loss.kind
  end

  ###
  # A store that is down, or a Solid Cache table that has not been created yet,
  # must never raise into the request serving the report.
  ###
  def test_reads_degrade_when_the_backend_is_unavailable
    session = build_session
    session.record({"a" => 1})

    target.define_singleton_method(:read) { |_key| raise "connection refused" }

    assert_equal({}, session.entries)
    assert_nil session.tracking_since
    assert_nil session.stored_size
  ensure
    target.singleton_class.remove_method(:read) if target.singleton_class.method_defined?(:read)
  end

  ###
  # A write the store refuses (rather than raises on) must keep the work, so the
  # next cycle retries it.
  ###
  def test_a_refused_write_keeps_the_work
    session = build_session
    session.enqueue({"a" => 1})
    target.define_singleton_method(:write) { |_key, _value, _options = {}| false }

    assert_equal :retained, session.flush
    assert_equal 1, session.pending_size, "a refused write must not lose the work"
  ensure
    target.singleton_class.remove_method(:write) if target.singleton_class.method_defined?(:write)
  end

  ###
  # A loss another process can see should say what actually happened, not be
  # flattened into "eviction".
  ###
  def test_persisted_data_loss_keeps_its_classification
    session = build_session(max_age: -1)
    session.enqueue({"a" => 1})
    session.flush # dropped by the age cap
    assert_equal :pending_dropped, session.data_loss.kind

    observer = build_session
    observer.entries # the report reads the document, then asks about losses
    assert_equal :pending_dropped, observer.data_loss&.kind,
      "another process has to see what kind of loss it was"
  end

  ###
  # A quiet document may never write another delta, so a loss recorded against
  # it has to be able to reach storage on its own.
  ###
  def test_data_loss_is_persisted_without_a_following_delta
    session = build_session
    session.record({"a" => 1})
    target.delete(session.send(:data_key))
    session.entries # notices the eviction
    session.flush # the next reporting cycle, with nothing new to say

    observer = build_session
    observer.entries
    assert_equal :eviction, observer.data_loss&.kind
  end

  ###
  # A marker whose write was refused is not durable. Believing otherwise drops
  # the only record that anything was lost.
  ###
  def test_a_refused_loss_marker_write_is_retried
    session = build_session(max_age: -1)
    session.entries # establish the pointer before the document write fails

    # only the document write is refused; the pointer is fine
    target.define_singleton_method(:write) do |key, value, options = {}|
      key.include?(".g") ? false : super(key, value, options)
    end
    session.enqueue({"a" => 1})
    session.flush # the loss happens, but the document cannot be written
    assert_equal :pending_dropped, session.data_loss.kind
    target.singleton_class.remove_method(:write)

    session.flush # storage is back
    observer = build_session
    observer.entries
    assert_equal :pending_dropped, observer.data_loss&.kind,
      "the marker has to survive a write that did not land"
  end

  def test_reports_states_rather_than_outcomes
    session = build_session
    assert_equal :written_unconfirmed, session.record({"a" => 1})
    assert_equal :confirmed, session.flush
    assert_equal :deferred, session.flush
  end

  ###
  # A writer that saw its own watermark and then finds it gone cannot tell
  # "pruned but applied" from "never applied". Re-applying could double count
  # and assuming durability could lose data, so it becomes a different writer
  # and gives up the ambiguous deltas -- reported, never silent.
  ###
  def test_a_vanished_watermark_rotates_identity_rather_than_guessing
    session = build_session
    session.record({"a" => 1})
    session.flush # reads its own watermark back, which is what makes it ambiguous later
    before = session.instance_variable_get(:@writer).writer_id

    # the watermark is pruned while this writer's delta is still pending
    session.enqueue({"a" => 1})
    doc = session.send(:operation) { session.send(:document) }
    doc.applied.clear
    session.send(:operation) { session.send(:write, doc) }

    session.flush

    refute_equal before, session.instance_variable_get(:@writer).writer_id,
      "an ambiguous watermark has to be given up, not guessed at"
    assert_equal :identity_rotated, session.data_loss.kind
    assert_equal 0, session.pending_size
  end

  ###
  # Coverband writes deltas, not heartbeats, so a document that stops seeing new
  # keys stops being written and ages out of a cache that expires by write age.
  ###
  def test_a_quiet_document_is_kept_alive
    session = build_session(keep_alive_after: 60)
    session.record({"a" => 1})
    session.instance_variable_set(:@last_write_at, Time.now.to_i - 10_000)

    writes = 0
    original = target.method(:write)
    target.define_singleton_method(:write) do |*args, **kw|
      writes += 1
      original.call(*args, **kw)
    end

    session.flush # nothing new, but the document is old enough to touch
    assert_operator writes, :>, 0, "a quiet document has to be refreshed, or it expires"
  ensure
    target.singleton_class.remove_method(:write) if target.singleton_class.method_defined?(:write)
  end

  def test_a_quiet_document_is_not_touched_before_its_time
    session = build_session(keep_alive_after: 10_000)
    session.record({"a" => 1})

    writes = 0
    original = target.method(:write)
    target.define_singleton_method(:write) do |*args, **kw|
      writes += 1
      original.call(*args, **kw)
    end

    session.flush
    assert_equal 0, writes, "touching every quiet cycle would rewrite the document forever"
  ensure
    target.singleton_class.remove_method(:write) if target.singleton_class.method_defined?(:write)
  end

  ###
  # The byte cap is the one that protects against a few enormous deltas rather
  # than many small ones, and it always leaves one behind: dropping everything
  # would lose the work whose size caused the problem, with nothing to report.
  ###
  def test_the_byte_cap_drops_oldest_and_keeps_one
    session = build_session(max_entries: 100, max_bytes: 200)
    5.times { |i| session.enqueue({"k#{i}" => "x" * 100}) }

    dropped = session.instance_variable_get(:@writer).enforce_caps!

    refute_empty dropped, "a queue past the byte cap has to shed something"
    assert_equal 1, session.pending_size, "and stop at one rather than emptying itself"
  end

  ###
  # Losing an initialization race is not a reset: the deltas went to a
  # generation that can never become authoritative, so carrying them forward
  # cannot double count. Dropping them would lose the cycle for nothing.
  ###
  def test_a_lost_initialization_race_carries_work_forward
    session = build_session(key_base: "conformance.race")
    session.enqueue({"a" => 1})
    session.send(:operation) {}
    session.instance_variable_set(:@initialized_token, true)

    # another process won the race, and its pointer names a token we never held
    generation = session.instance_variable_get(:@generation)
    result = Coverband::Storage::Generation::Result.new(
      token: "winner", initialized: false, pointer: {"token" => "winner", "retire" => []},
      pointer_missing: false
    )
    session.send(:on_generation_changed, result)

    if target.respond_to?(:atomic_create?) && target.atomic_create?
      # a backend that creates atomically cannot produce a race, so an
      # unexplained token change is a reset, and carrying work across a
      # deliberate clear is the worse mistake
      assert_equal 0, session.pending_size,
        "without a race to explain it, a new token is a reset"
    else
      assert_equal 1, session.pending_size,
        "work bound for a generation that lost a race is still unreported work"
    end
  ensure
    generation&.reset!
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
