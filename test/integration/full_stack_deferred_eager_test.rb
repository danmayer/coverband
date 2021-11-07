# frozen_string_literal: true

require File.expand_path("../test_helper", File.dirname(__FILE__))
require "rack"

class FullStackDeferredEagerTest < Minitest::Test
  REDIS_STORAGE_FORMAT_VERSION = Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION
  TEST_RACK_APP = "../fake_app/basic_rack.rb"

  def setup
    super
    Coverband::Collectors::Coverage.instance.reset_instance
    Coverband.configure do |config|
      config.background_reporting_enabled = false
      config.track_gems = true
      config.defer_eager_loading_data = true
    end
    Coverband.start
    Coverband::Collectors::Coverage.instance.eager_loading!
    @rack_file = require_unique_file "fake_app/basic_rack.rb"
    Coverband.report_coverage
    Coverband::Collectors::Coverage.instance.runtime!
  end

  test "call app" do
    # eager loaded class coverage starts empty
    Coverband.eager_loading_coverage!
    expected = {}
    assert_equal expected, Coverband.configuration.store.coverage

    Coverband::Collectors::Coverage.instance.runtime!
    request = Rack::MockRequest.env_for("/anything.json")
    middleware = Coverband::BackgroundMiddleware.new(fake_app_with_lines)
    results = middleware.call(request)
    assert_equal "Hello Rack!", results.last
    Coverband.report_coverage
    expected = [nil, nil, 0, nil, 0, 0, 1, nil, nil]
    assert_equal expected, Coverband.configuration.store.coverage[@rack_file]["data"]

    # eager loaded class coverage is saved at first normal coverage report
    Coverband.eager_loading_coverage!
    expected = [nil, nil, 1, nil, 1, 1, 0, nil, nil]
    assert_equal expected, Coverband.configuration.store.coverage[@rack_file]["data"]
  end

  private

  def fake_app_with_lines
    @fake_app_with_lines ||= ::HelloWorld.new
  end
end
