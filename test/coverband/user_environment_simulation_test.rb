# frozen_string_literal: true

# This test simulates using Coverband without COVERBAND_DISABLE_AUTO_START
# to see if the issue still occurs

require File.expand_path("../test_helper", File.dirname(__FILE__))

class UserEnvironmentSimulationTest < Minitest::Test
  def setup
    super
    # Clean slate
    Thread.current[:coverband_instance] = nil
  end

  def teardown
    super
    Thread.current[:coverband_instance] = nil
    # Restore the configured state
    Coverband.configure do |config|
      # Use default config
    end
    ENV.delete("COVERBAND_DISABLE_AUTO_START")
  end

  test "user workflow with auto-start disabled" do
    # User disables auto-start and configures manually (recommended approach)
    ENV["COVERBAND_DISABLE_AUTO_START"] = "true"

    begin
      # Reset state
      Coverband.class_variable_set(:@@configured, false)
      Coverband.configuration.instance_variable_set(:@store, nil)

      # User configuration exactly like the GitHub issue
      Coverband.configure do |config|
        config.root = Dir.pwd
        config.background_reporting_enabled = false
        config.store = Coverband::Adapters::FileStore.new("tmp/coverband_log")
        config.logger = Logger.new($stdout)
        config.verbose = false
      end

      # Start manually
      Coverband.start

      # Should use FileStore without any Redis errors
      assert_instance_of Coverband::Adapters::FileStore, Coverband.configuration.store

      # These operations should work fine
      Coverband.report_coverage
    ensure
      ENV.delete("COVERBAND_DISABLE_AUTO_START")
    end
  end

  test "multiple reports with FileStore should never try Redis" do
    Coverband.configure do |config|
      config.root = Dir.pwd
      config.background_reporting_enabled = false
      config.store = Coverband::Adapters::FileStore.new("tmp/test_multiple_reports")
      config.logger = Logger.new($stdout)
      config.verbose = false
    end

    # Mock Redis to ensure it's never called after proper configuration
    Redis.expects(:new).never

    # Multiple reports should work fine
    5.times do
      Coverband.report_coverage
    end

    assert_instance_of Coverband::Adapters::FileStore, Coverband.configuration.store
  end
end
