# frozen_string_literal: true

# This test simulates the exact scenario from GitHub issue #586
# to verify the timing and sequence of initialization

require File.expand_path("../test_helper", File.dirname(__FILE__))

class InitializationTimingTest < Minitest::Test
  def setup
    super
    # Clear all state to simulate fresh require
    Thread.current[:coverband_instance] = nil
    Coverband.class_variable_set(:@@configured, false)
    Coverband.configuration.instance_variable_set(:@store, nil)
  end

  def teardown
    super
    Thread.current[:coverband_instance] = nil
    Coverband.configure do |config|
      # Reset to default
    end
    Coverband.class_variable_set(:@@configured, false)
  end

  test "simulate auto-start before user configuration" do
    # Clear configuration to simulate fresh require
    Coverband.configuration.instance_variable_set(:@store, nil)
    Coverband.class_variable_set(:@@configured, false)

    # Mock Redis to fail when auto-start tries to create default store
    Redis.expects(:new).raises(Redis::CannotConnectError.new("Connection refused")).once

    # This simulates what happens during auto-start (configure + start)
    # before user has configured anything
    Coverband.configure  # No block, no file
    Coverband.start

    # At this point, the store should have fallen back to NullStore
    assert_instance_of Coverband::Adapters::NullStore, Coverband.configuration.store

    # Now user tries to configure with FileStore
    Coverband.configure do |config|
      config.store = Coverband::Adapters::FileStore.new("coverband/log")
    end

    # Should now use the configured FileStore
    assert_instance_of Coverband::Adapters::FileStore, Coverband.configuration.store
  end

  test "check what happens if store is accessed before user configures it" do
    # Clear configuration to simulate unconfigured state
    Coverband.configuration.instance_variable_set(:@store, nil)
    Coverband.class_variable_set(:@@configured, false)

    # Mock Redis to fail
    Redis.expects(:new).raises(Redis::CannotConnectError.new("Connection refused")).once

    # Access store before configuration - should trigger fallback
    store = Coverband.configuration.store
    assert_instance_of Coverband::Adapters::NullStore, store

    # Now configure with FileStore
    Coverband.configure do |config|
      config.store = Coverband::Adapters::FileStore.new("coverband/log")
    end

    # Should now use the configured FileStore
    assert_instance_of Coverband::Adapters::FileStore, Coverband.configuration.store
  end
end
