# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "active_support"
require "active_support/cache"

###
# Trackers used to reach through the store to raw Redis commands, so only Redis
# backed stores could track anything. They now talk to a repository, and the
# repository picks its layout from the merge semantics rather than the backend.
###
module TrackerStorageBehavior
  def presence_merger
    lambda do |doc, delta|
      delta.payload.each do |key, value|
        next if doc.tombstoned?(key, delta.tombstone_epoch)

        existing = doc.payload[key.to_s]
        doc.payload[key.to_s] = value.to_s if existing.nil? || existing.to_i < value.to_i
      end
    end
  end

  def repository(name = "ExampleTracker", idempotent: true)
    factory.for(name, merger: presence_merger, idempotent: idempotent)
  end

  def test_records_and_reads_back_string_values
    repo = repository
    repo.record({"a" => 100})
    assert_equal({"a" => "100"}, repo.entries)
  end

  ###
  # Redis hgetall hands back strings and JSON parsing does not, so the two
  # implementations would otherwise not be interchangeable for callers.
  ###
  def test_value_types_match_across_implementations
    repo = repository
    repo.record({"a" => 1})
    repo.entries.each_value { |value| assert_kind_of String, value }
  end

  def test_tracking_since_is_owned_by_the_repository
    repo = repository
    assert_nil repo.tracking_since
    repo.record({"a" => 1})
    assert_kind_of Time, repo.tracking_since
  end

  def test_delete_entry_removes_a_key
    repo = repository
    repo.record({"a" => 1, "b" => 2})
    repo.delete_entry("a")
    assert_equal ["b"], repo.entries.keys
  end

  def test_reset_clears_and_advances_the_generation
    repo = repository
    repo.record({"a" => 1})
    before = repo.generation
    assert repo.reset
    refute_equal before, repo.generation
    assert_equal({}, repo.entries)
    assert_nil repo.tracking_since
  end

  def test_presence_recording_is_idempotent
    repo = repository
    repo.record({"a" => 5})
    repo.record({"a" => 5})
    assert_equal({"a" => "5"}, repo.entries)
  end

  def test_later_timestamp_wins
    repo = repository
    repo.record({"a" => 10})
    repo.record({"a" => 20})
    assert_equal "20", repo.entries["a"]
  end
end

class CacheTrackerStorageTest < Minitest::Test
  include TrackerStorageBehavior

  def setup
    super
    @factory = Coverband::Adapters::TrackerStorage::Cache.new(
      target: Coverband::Storage::Target.new(ActiveSupport::Cache::MemoryStore.new),
      namespace: "coverband_test",
      format_version: "test_1_0"
    )
  end

  attr_reader :factory

  ###
  # Cache presence merging is idempotent, but the watermark is still what tells
  # a writer that a stale whole document write erased its key. Without that the
  # loser's permanent local dedupe would never enqueue the key again.
  ###
  def test_stale_write_is_detected_and_repaired
    a = repository
    b = repository
    a.record({"kept" => 1})
    b.record({"other" => 2})

    3.times do
      a.record({})
      b.record({})
    end

    assert_equal %w[kept other].sort, a.entries.keys.sort
  end

  def test_reports_deletions_so_local_dedupe_can_be_invalidated
    a = repository
    b = repository
    a.record({"gone" => 1})
    b.entries
    b.newly_tombstoned # drain the initial read

    a.delete_entry("gone")
    b.entries
    assert_includes b.newly_tombstoned, "gone"
  end

  def test_repository_retains_pending_itself
    assert repository.retains_pending?
  end
end

class RedisTrackerStorageTest < Minitest::Test
  include TrackerStorageBehavior

  def setup
    super
    @factory = Coverband::Adapters::TrackerStorage::Redis.new(
      redis: Coverband::Test.redis,
      namespace: "coverband_test",
      format_version: "test_1_0"
    )
  end

  attr_reader :factory

  ###
  # Presence trackers keep native per field writes: a field written by one
  # process is never reverted by another's write, which is stronger than
  # anything a whole document protocol offers.
  ###
  def test_presence_trackers_use_a_redis_hash
    repo = repository
    assert_kind_of Coverband::Adapters::TrackerStorage::RedisHashRepository, repo
    refute repo.retains_pending?
  end

  ###
  # Additive trackers can't use the hash. A stale multi field HSET leaves
  # another writer's field in place while wiping the metadata that recorded it,
  # so that writer would see no watermark and apply its delta twice.
  ###
  def test_additive_trackers_use_a_document
    repo = repository("QueryBurstTracker", idempotent: false)
    assert_kind_of Coverband::Adapters::TrackerStorage::DocumentRepository, repo
    assert repo.retains_pending?
  end

  def test_hash_and_document_layouts_agree_on_reads
    hash_repo = repository("Presence")
    doc_repo = repository("Additive", idempotent: false)
    hash_repo.record({"a" => 1})
    doc_repo.record({"a" => 1})
    assert_equal hash_repo.entries, doc_repo.entries
  end
end
