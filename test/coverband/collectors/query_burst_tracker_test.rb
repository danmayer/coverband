# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class QueryBurstTrackerTest < Minitest::Test
  def tracker
    Coverband::Collectors::QueryBurstTracker.expects(:supported_version?).at_least_once.returns(true)
    Coverband::Collectors::QueryBurstTracker.new(store: fake_store)
  end

  def tracker_key
    tracker.send(:tracker_key)
  end

  def tracker_time_key
    tracker.send(:tracker_time_key)
  end

  def setup
    super
    fake_store.raw_store.del(tracker_key)
    fake_store.raw_store.del(tracker_time_key)
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

  protected

  def fake_store
    @fake_store ||= Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
  end
end
