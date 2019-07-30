# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))
require 'rack'

class FullStackTest < Minitest::Test
  REDIS_STORAGE_FORMAT_VERSION = Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION
  TEST_RACK_APP = '../fake_app/basic_rack.rb'

  def setup
    super
    Coverband::Collectors::Coverage.instance.reset_instance
    Coverband.configure do |config|
      config.store = Coverband::Adapters::RedisStore.new(Redis.new, redis_namespace: 'coverband_test')
      config.s3_bucket = nil
      config.background_reporting_enabled = true
      config.track_gems = true
    end
    Coverband.configuration.store.clear!
    Coverband.start
    Coverband::Collectors::Coverage.instance.eager_loading!
    @rack_file = require_unique_file 'fake_app/basic_rack.rb'
    Coverband.report_coverage
    Coverband::Collectors::Coverage.instance.runtime!
  end

  test 'call app' do
    request = Rack::MockRequest.env_for('/anything.json')
    middleware = Coverband::BackgroundMiddleware.new(fake_app_with_lines)
    results = middleware.call(request)
    assert_equal 'Hello Rack!', results.last
    Coverband.report_coverage
    expected = [nil, nil, 0, nil, 0, 0, 1, nil, nil]
    assert_equal expected, Coverband.configuration.store.coverage[@rack_file]['data']

    # additional calls increase count by 1
    middleware.call(request)
    Coverband.report_coverage
    expected = [nil, nil, 0, nil, 0, 0, 2, nil, nil]
    assert_equal expected, Coverband.configuration.store.coverage[@rack_file]['data']

    # class coverage
    Coverband.eager_loading_coverage!
    Coverband.configuration.store.coverage[@rack_file]['data']
    expected = [nil, nil, 1, nil, 1, 1, 0, nil, nil]
  end

  test 'call app with gem tracking' do
    require 'rainbow'
    Rainbow('this text is red').red
    request = Rack::MockRequest.env_for('/anything.json')
    middleware = Coverband::BackgroundMiddleware.new(fake_app_with_lines)
    results = middleware.call(request)
    assert_equal 'Hello Rack!', results.last
    Coverband.report_coverage
    assert Coverband.configuration.store.coverage.keys.any? { |key| key.end_with?('rainbow/global.rb') }
  end

  private

  def fake_app_with_lines
    @fake_app_with_lines ||= ::HelloWorld.new
  end
end
