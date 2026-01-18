# frozen_string_literal: true

# This test demonstrates the fix for GitHub issue #586
# https://github.com/danmayer/coverband/issues/586

require File.expand_path("../test_helper", File.dirname(__FILE__))

class GitHubIssue586Test < Minitest::Test
  def setup
    super
    # Reset the singleton instance to ensure clean state
    Coverband::Collectors::Coverage.instance.reset_instance
  end

  def teardown
    super
    Thread.current[:coverband_instance] = nil
    Coverband.configure do |config|
      # Reset to default
    end
    Coverband::Collectors::Coverage.instance.reset_instance
  end

  test "GitHub issue #586: FileStore should not cause Redis connection errors" do
    # This reproduces the exact configuration from the GitHub issue
    Coverband.configure do |config|
      config.root = Dir.pwd
      config.background_reporting_enabled = false
      config.store = Coverband::Adapters::FileStore.new("tmp/coverband_log")
      config.logger = Logger.new($stdout)
      config.verbose = false
    end

    # This should not raise Redis connection errors
    begin
      # Simulate running ruby code to analyze
      Coverband.start
      Coverband.report_coverage

      # Verify the store is what the user configured
      assert_instance_of Coverband::Adapters::FileStore, Coverband.configuration.store
    rescue Redis::CannotConnectError => e
      flunk "Should not get Redis connection error when using FileStore: #{e.message}"
    end
  end
end
