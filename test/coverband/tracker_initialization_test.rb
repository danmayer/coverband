# frozen_string_literal: true

require File.expand_path("../test_helper", File.dirname(__FILE__))

class TrackerInitializationTest < Minitest::Test
  def setup
    super
    Thread.current[:coverband_instance] = nil
  end

  def teardown
    super
    Thread.current[:coverband_instance] = nil
    Coverband.configure do |config|
      # Reset
    end
  end

  test "tracker initialization can trigger Redis connection" do
    skip "ViewTracker requires Rails 7+" unless defined?(Rails::VERSION) && Rails::VERSION::STRING.split(".").first.to_i >= 7

    # Reset everything
    Coverband.configuration.instance_variable_set(:@store, nil)
    Coverband.configuration.instance_variable_set(:@view_tracker, nil)

    # Mock Redis to see if it gets called when trackers are created
    Redis.expects(:new).raises(Redis::CannotConnectError.new("Connection refused")).once

    # This could happen during railtie initialization
    # Creating a view tracker when no store is configured yet
    Coverband.configuration.railtie!

    # Should have fallen back to NullStore due to Redis error
    assert_instance_of Coverband::Adapters::NullStore, Coverband.configuration.store
  end

  test "tracker initialization after FileStore config works fine" do
    skip "ViewTracker requires Rails 7+" unless defined?(Rails::VERSION) && Rails::VERSION::STRING.split(".").first.to_i >= 7

    # Configure FileStore first
    Coverband.configure do |config|
      config.store = Coverband::Adapters::FileStore.new("tmp/tracker_test")
      config.track_views = true
    end

    # Redis should never be attempted
    Redis.expects(:new).never

    # Creating trackers should use the configured FileStore
    Coverband.configuration.railtie!

    assert_instance_of Coverband::Adapters::FileStore, Coverband.configuration.store
    assert_instance_of Coverband::Collectors::ViewTracker, Coverband.configuration.view_tracker
  end

  test "store configuration prevents Redis connection in tracker contexts" do
    # Test the core issue without Rails dependency
    # Configure FileStore first
    Coverband.configure do |config|
      config.store = Coverband::Adapters::FileStore.new("tmp/abstract_tracker_test")
    end

    # Redis should never be attempted
    Redis.expects(:new).never

    # This tests that the store getter works correctly
    # when called from tracker initialization contexts
    store = Coverband.configuration.store
    assert_instance_of Coverband::Adapters::FileStore, store

    # Multiple accesses should return the same cached instance
    store2 = Coverband.configuration.store
    assert_same store, store2
  end
end
