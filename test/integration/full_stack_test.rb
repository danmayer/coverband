# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))
require 'rack'

class FullStackTest < Minitest::Test
  REDIS_STORAGE_FORMAT_VERSION = Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION
  TEST_RACK_APP = '../fake_app/basic_rack.rb'
  RELATIVE_FILE = './fake_app/basic_rack.rb'

  def setup
    super
    Coverband::Collectors::Coverage.instance.reset_instance
    Coverband.configure do |config|
      config.reporting_frequency = 100.0
      config.store = Coverband::Adapters::RedisStore.new(Redis.new)
      config.s3_bucket = nil
      config.background_reporting_enabled = false
      config.root_paths = ["#{File.expand_path('../', File.dirname(__FILE__))}/"]
      config.track_gems = true
    end
    Coverband.configuration.store.clear!
    Coverband.start
    Coverband::Collectors::Coverage.instance.runtime!
    @rack_file = File.expand_path(TEST_RACK_APP, File.dirname(__FILE__))
    require @rack_file
    # preload first coverage hit
    Coverband::Collectors::Coverage.instance.report_coverage(true)
  end

  test 'call app' do
    request = Rack::MockRequest.env_for('/anything.json')
    middleware = Coverband::Middleware.new(fake_app_with_lines)
    results = middleware.call(request)
    assert_equal 'Hello Rack!', results.last
    sleep(0.2)
    expected = [nil, nil, 1, nil, 1, 1, 1, nil, nil]
    assert_equal expected, Coverband.configuration.store.coverage[RELATIVE_FILE]['data']

    # additional calls increase count by 1
    middleware.call(request)
    sleep(0.2)
    expected = [nil, nil, 1, nil, 1, 1, 2, nil, nil]
    assert_equal expected, Coverband.configuration.store.coverage[RELATIVE_FILE]['data']
  end

  test 'call app with gem tracking' do
    require 'rainbow'
    Rainbow('this text is red').red
    request = Rack::MockRequest.env_for('/anything.json')
    middleware = Coverband::Middleware.new(fake_app_with_lines)
    results = middleware.call(request)
    assert_equal 'Hello Rack!', results.last
    sleep(0.1)
    assert Coverband.configuration.store.coverage.keys.any? { |key| key.end_with?('rainbow/global.rb') }
  end

  private

  def fake_app_with_lines
    @fake_app_with_lines ||= ::HelloWorld.new
  end
end
