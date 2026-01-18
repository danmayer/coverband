# frozen_string_literal: true

require File.expand_path("../test_helper", File.dirname(__FILE__))

class FileStoreIntegrationTest < Minitest::Test
  def setup
    super
    # Reset state
    Thread.current[:coverband_instance] = nil
    Coverband.class_variable_set(:@@configured, false)
  end

  def teardown
    super
    Thread.current[:coverband_instance] = nil
    Coverband.configure do |config|
      # Reset to default
    end
    Coverband.class_variable_set(:@@configured, false)
  end

  test "auto-start with FileStore configuration does not try Redis" do
    # Clear any existing store to simulate fresh start
    Coverband.configuration.instance_variable_set(:@store, nil)

    # This simulates the typical user setup
    Coverband.configure do |config|
      config.root = Dir.pwd
      config.background_reporting_enabled = false
      config.store = Coverband::Adapters::FileStore.new("tmp/integration_test_coverage")
      config.logger = Logger.new($stdout)
      config.verbose = false
    end

    # Start coverband - this should work without Redis errors
    begin
      Coverband.start
      Coverband.report_coverage
    rescue Redis::CannotConnectError => e
      flunk "Should not try to connect to Redis when FileStore is configured: #{e.message}"
    rescue => e
      flunk "Unexpected error: #{e.class}: #{e.message}"
    end

    # Verify we're using the correct store
    assert_instance_of Coverband::Adapters::FileStore, Coverband.configuration.store
  end

  test "store fallback works even in auto-start scenario" do
    # Backup original ENV to avoid side effects
    original_disable = ENV["COVERBAND_DISABLE_AUTO_START"]

    begin
      # Enable auto-start
      ENV.delete("COVERBAND_DISABLE_AUTO_START")

      # Clear configuration state
      Coverband.configuration.instance_variable_set(:@store, nil)
      Coverband.class_variable_set(:@@configured, false)

      # Mock Redis to fail
      Redis.expects(:new).raises(Redis::CannotConnectError.new("Connection refused")).at_least_once

      # This should not raise an error even with Redis unavailable
      store = Coverband.configuration.store

      assert_instance_of Coverband::Adapters::NullStore, store
    ensure
      ENV["COVERBAND_DISABLE_AUTO_START"] = original_disable
    end
  end
end
