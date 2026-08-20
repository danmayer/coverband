# frozen_string_literal: true

require File.expand_path("../rails_test_helper", File.dirname(__FILE__))

class RailsCacheFullStackTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def skip_coverband_test_reset?
    true
  end

  def setup
    super
    ENV["COVERBAND_RAILS_CACHE"] = "true"
    rails_setup
    # Keep this assertion meaningful when contributors run the suite from a
    # temporary worktree; /tmp is ignored by default for deploy-time builds.
    Coverband.configuration.ignore.delete_if { |pattern| pattern.source == "/tmp" }
    Coverband::Collectors::Coverage.instance.reset_instance
    Coverband.report_coverage
  end

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver
    Coverband::Background.stop
    ENV.delete("COVERBAND_RAILS_CACHE")
    super
  end

  test "Rails.cache stores coverage and tracker data through a full Rails lifecycle" do
    assert_instance_of ActiveSupport::Cache::MemoryStore, Rails.cache

    store = Coverband.configuration.store
    assert_instance_of Coverband::Adapters::ActiveSupportCacheStore, store

    visit "/dummy/show"
    assert_content("I am no dummy")

    dummy_controller = "./app/controllers/dummy_controller.rb"
    coverage = nil
    5.times do
      Coverband.report_coverage
      coverage = store.coverage
      break if coverage.key?(dummy_controller)
    end
    assert coverage.key?(dummy_controller), "stored coverage keys: #{coverage.keys.inspect}"

    route_tracker = Coverband.configuration.route_tracker
    assert_same store, route_tracker.store
    route_tracker.save_report
    assert route_tracker.used_keys.keys.any? { |route| route.include?("dummy") && route.include?("show") }

    visit "/coverage"
    assert_selector("a", text: /dummy_controller.rb/)

    visit "/coverage/routes_tracker"
    assert_content(/controller(?::|=>)\s*"dummy"/)
    assert_content(/action(?::|=>)\s*"show"/)
  end
end
