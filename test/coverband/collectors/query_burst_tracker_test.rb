# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class QueryBurstTrackerTest < Minitest::Test
  def tracker
    Coverband::Collectors::QueryBurstTracker.expects(:supported_version?).at_least_once.returns(true)
    Coverband::Collectors::QueryBurstTracker.new(store: fake_store)
  end

  def setup
    super
  end

  test "track key aggregates request SQL stats and threshold hits" do
    Coverband.configuration.query_burst_query_count_threshold = 30
    Coverband.configuration.query_burst_sql_time_threshold_ms = 100.0

    subject = tracker
    key = "controller:users#index"

    subject.track_key(key: key, queries: 40, sql_time_ms: 120.5)
    subject.track_key(key: key, queries: 10, sql_time_ms: 20.0)
    subject.save_report

    assert_equal [key], subject.used_keys.keys

    stats = subject.used_key_stats[key]
    assert_equal 2, stats["requests"]
    assert_equal 50, stats["total_queries"]
    assert_equal 140.5, stats["total_sql_time_ms"]
    assert_equal 40, stats["max_queries"]
    assert_equal 120.5, stats["max_sql_time_ms"]
    assert_equal 1, stats["threshold_hits"]
  end

  test "as_json includes thresholds and tracked keys" do
    subject = tracker
    key = "job:HardWorker queue:default"

    subject.track_key(key: key, queries: 3, sql_time_ms: 12.0)
    subject.save_report

    parsed = JSON.parse(subject.as_json)
    assert_equal Coverband.configuration.query_burst_query_count_threshold, parsed.dig("thresholds", "query_count")
    assert_equal Coverband.configuration.query_burst_sql_time_threshold_ms, parsed.dig("thresholds", "sql_time_ms")
    assert parsed["used_keys"].key?(key)
  end

  test "clear key removes tracked query burst stats" do
    subject = tracker
    key = "controller:orders#show"

    subject.track_key(key: key, queries: 31, sql_time_ms: 55.0)
    subject.save_report
    assert_equal [key], subject.used_keys.keys

    subject.clear_key!(key)
    assert_equal [], subject.used_keys.keys
  end

  ###
  # Unsaved aggregates live outside the key sets the parent clears, so a reset
  # that misses them writes pre-reset counters into the new generation.
  ###
  test "reset does not carry unsaved counters into the new generation" do
    subject = tracker
    subject.track_key(key: "controller:dogs#index", queries: 12, sql_time_ms: 50.0)
    subject.reset_recordings
    subject.save_report

    assert_equal({}, subject.used_key_stats)
  end

  ###
  # Same for a single key: clearing it must not leave its counters queued to be
  # written straight back.
  ###
  test "clear_key does not leave the cleared key queued" do
    subject = tracker
    subject.track_key(key: "controller:dogs#index", queries: 12, sql_time_ms: 50.0)
    subject.save_report
    assert_includes subject.used_key_stats.keys, "controller:dogs#index"

    subject.track_key(key: "controller:dogs#index", queries: 3, sql_time_ms: 5.0)
    subject.clear_key!("controller:dogs#index")
    subject.save_report

    refute_includes subject.used_key_stats.keys, "controller:dogs#index"
  end

  protected

  ###
  # A tracker keeps its own counters when a report does not land, and the
  # storage layer holds nothing for it -- otherwise both replay the same work
  # and these counters, which sum, come out doubled.
  ###
  test "a failed report is not counted twice when it is retried" do
    require "active_support"
    require "active_support/cache"

    cache = ActiveSupport::Cache::MemoryStore.new
    store = Coverband::Adapters::ActiveSupportCacheStore.new(cache, cache_namespace: "burst_retry")
    Coverband::Collectors::QueryBurstTracker.expects(:supported_version?).at_least_once.returns(true)
    subject = Coverband::Collectors::QueryBurstTracker.new(store: store)
    subject.track_key(key: "controller:books#index", queries: 40, sql_time_ms: 120.0)

    cache.stubs(:read).raises(RuntimeError.new("backend down"))
    subject.save_report # logged and swallowed, counters kept

    cache.unstub(:read)
    subject.save_report
    subject.save_report

    assert_equal 1, subject.used_key_stats["controller:books#index"]["requests"],
      "one request was observed, so one request has to be stored"
  end

  ###
  # An unreachable backend must not be lossier than one that raises. A tracker's
  # key set is unbounded and re-supplied every cycle; the storage queue is
  # capped, so handing the keys over and clearing them loses anything that
  # outlives the cap -- and the dedupe set stops it ever coming back.
  ###
  test "keys survive a backend that never becomes available" do
    require "active_support"
    require "active_support/cache"

    Coverband::Collectors::QueryBurstTracker.expects(:supported_version?).at_least_once.returns(true)
    ready = false
    cache = ActiveSupport::Cache::MemoryStore.new
    store = Coverband::Adapters::ActiveSupportCacheStore.new { ready ? cache : nil }
    subject = Coverband::Collectors::QueryBurstTracker.new(store: store)
    subject.track_key(key: "controller:books#index", queries: 40, sql_time_ms: 120.0)

    12.times { subject.save_report } # far past any cap the storage queue has

    ready = true
    subject.save_report

    assert_equal 1, subject.used_key_stats["controller:books#index"]["requests"],
      "an outage of any length has to be lossless while the tracker holds the keys"
  end

  ###
  # A write refused after the delta was enqueued is not the same as one refused
  # before it: storage has the work either way it is described, but only in the
  # second case is it the caller's again. Keeping a copy against the first gives
  # the delta two owners, and these counters sum.
  #
  # This is the documented memcached >1MB path, so it is reachable in ordinary
  # operation rather than only under injected faults.
  ###
  test "a write refused after the enqueue is not counted twice" do
    require "active_support"
    require "active_support/cache"

    Coverband::Collectors::QueryBurstTracker.expects(:supported_version?).at_least_once.returns(true)
    refusing = false
    cache = ActiveSupport::Cache::MemoryStore.new
    # the document only, never the pointer, which is the shape of a slab refusal
    cache.define_singleton_method(:write) do |key, *rest, **kw|
      next false if refusing && !key.to_s.end_with?(".pointer")
      super(key, *rest, **kw)
    end

    store = Coverband::Adapters::ActiveSupportCacheStore.new(cache, cache_namespace: "burst_refused")
    subject = Coverband::Collectors::QueryBurstTracker.new(store: store)

    subject.track_key(key: "controller:books#index", queries: 40, sql_time_ms: 10.0)
    subject.save_report # establishes the document

    refusing = true
    3.times do
      subject.track_key(key: "controller:books#index", queries: 40, sql_time_ms: 10.0)
      subject.save_report
    end

    refusing = false
    subject.save_report

    assert_equal 4, subject.used_key_stats["controller:books#index"]["requests"],
      "four requests were observed, so four have to be stored"
  end

  ###
  # The quiet cycle is the only chance storage gets to flush work it took but
  # could not write, so a tracker with nothing new of its own still has to ask.
  ###
  test "a quiet cycle still flushes work storage is holding" do
    require "active_support"
    require "active_support/cache"

    Coverband::Collectors::QueryBurstTracker.expects(:supported_version?).at_least_once.returns(true)
    refusing = false
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.define_singleton_method(:write) do |key, *rest, **kw|
      next false if refusing && !key.to_s.end_with?(".pointer")
      super(key, *rest, **kw)
    end

    store = Coverband::Adapters::ActiveSupportCacheStore.new(cache, cache_namespace: "burst_quiet")
    subject = Coverband::Collectors::QueryBurstTracker.new(store: store)
    subject.track_key(key: "controller:books#index", queries: 40, sql_time_ms: 10.0)
    subject.save_report

    refusing = true
    subject.track_key(key: "controller:books#index", queries: 40, sql_time_ms: 10.0)
    subject.save_report

    refusing = false
    subject.save_report # nothing new of its own

    assert_equal 2, subject.used_key_stats["controller:books#index"]["requests"],
      "retained work has to land without waiting for the next burst"
  end

  def fake_store
    @fake_store ||= Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
  end
end
