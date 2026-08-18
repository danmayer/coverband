# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "active_support"
require "active_support/cache"

###
# With a database backed cache (Solid Cache) Coverband's own storage I/O is
# SQL. Left unfiltered it lands on whatever controller action or job triggered
# the report, inflating its query count and potentially tripping the very
# thresholds QueryBurstTracker exists to detect.
###
class StorageIOGuardTest < Minitest::Test
  def test_guard_is_off_by_default
    refute Coverband::Storage::IOGuard.active?
  end

  def test_guard_is_nesting_safe
    Coverband::Storage::IOGuard.guard do
      Coverband::Storage::IOGuard.guard do
        assert Coverband::Storage::IOGuard.active?
      end
      assert Coverband::Storage::IOGuard.active?, "an inner block must not clear the guard"
    end
    refute Coverband::Storage::IOGuard.active?
  end

  ###
  # A raise inside storage I/O must not leave the guard set, or the app's real
  # queries would be silently ignored for the rest of the request.
  ###
  def test_guard_is_released_on_raise
    assert_raises(RuntimeError) do
      Coverband::Storage::IOGuard.guard { raise "boom" }
    end
    refute Coverband::Storage::IOGuard.active?
  end

  def test_guard_is_per_thread
    Coverband::Storage::IOGuard.guard do
      assert Coverband::Storage::IOGuard.active?
      Thread.new { refute Coverband::Storage::IOGuard.active? }.join
    end
  end

  ###
  # Reads count as much as writes: the pointer read happens every cycle, so a
  # read only quiet cycle would otherwise still pollute the stats.
  ###
  def test_every_call_into_the_cache_target_is_guarded
    recorder = Class.new do
      attr_reader :guarded

      def initialize
        @guarded = {}
      end

      def record(op)
        @guarded[op] = Coverband::Storage::IOGuard.active?
      end

      def read(_key)
        record(:read)
        nil
      end

      def read_multi(*_keys)
        record(:read_multi)
        {}
      end

      def write(_key, _value, _options = {})
        record(:write)
        true
      end

      def delete(_key)
        record(:delete)
        true
      end

      def exist?(_key)
        record(:exist)
        false
      end
    end.new

    target = Coverband::Storage::Target.new(recorder)
    target.read("k")
    target.read_multi("k")
    target.write("k", "v")
    target.delete("k")
    target.exist?("k")

    assert_equal({read: true, read_multi: true, write: true, delete: true, exist: true}, recorder.guarded)
  end
end

class QueryBurstStorageFeedbackTest < Minitest::Test
  def setup
    super
    Coverband::Collectors::QueryBurstTracker.stubs(:supported_version?).returns(true)
    @tracker = Coverband::Collectors::QueryBurstTracker.new(
      store: Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
    )
  end

  def test_sql_from_coverbands_own_storage_is_ignored
    payload = {name: "Dog Load", sql: "SELECT 1"}
    refute @tracker.send(:ignore_sql_event?, payload)

    Coverband::Storage::IOGuard.guard do
      assert @tracker.send(:ignore_sql_event?, payload),
        "Coverband's own storage queries must not be blamed on the request"
    end
  end

  ###
  # A report issued inside a request would otherwise attribute Coverband's own
  # writes to the surrounding controller action.
  ###
  def test_reporting_inside_a_tracked_context_contributes_no_queries
    @tracker.send(:start_context, :controller, "controller:dogs#index")
    Coverband::Storage::IOGuard.guard do
      @tracker.send(:record_sql_event, 5.0) unless @tracker.send(:ignore_sql_event?, {name: "Dog Load"})
    end
    @tracker.send(:finish_context, :controller, "controller:dogs#index")
    @tracker.save_report

    stats = @tracker.used_key_stats["controller:dogs#index"]
    assert_equal 0, stats["total_queries"], "Coverband's own storage I/O must not count"
  end
end
