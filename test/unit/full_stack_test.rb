# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))
require 'rack'

class FullStackTest < Test::Unit::TestCase
  BASE_KEY = Coverband::Adapters::RedisStore::BASE_KEY
  TEST_RACK_APP = '../fake_app/basic_rack.rb'.freeze

  def setup
    Coverband::Collectors::Base.instance.reset_instance
    Coverband.configure do |config|
      config.reporting_frequency = 100.0
      config.store = Coverband::Adapters::RedisStore.new(Redis.new)
      config.s3_bucket = nil
    end
    Coverband.configuration.store.clear!
    Coverband.start
    @rack_file = File.expand_path(TEST_RACK_APP, File.dirname(__FILE__))
    require @rack_file
  end

  test 'call app' do
    request = Rack::MockRequest.env_for('/anything.json')
    middleware = Coverband::Middleware.new(fake_app_with_lines)
    results = middleware.call(request)
    assert_equal 'Hello Rack!', results.last
    expected = [nil, nil, 1, nil, 1, 1, 1, nil, nil]
    assert_equal expected, Coverband.configuration.store.coverage[@rack_file]

    # additional calls increase count by 1
    middleware.call(request)
    expected = [nil, nil, 1, nil, 1, 1, 2, nil, nil]
    assert_equal expected, Coverband.configuration.store.coverage[@rack_file]

    expected = nil
    # TODO: read the html to test it matches expectations? or return data as a hash?
    actual = Coverband::Reporters::SimpleCovReport.report(Coverband.configuration.store, open_report: false)
    assert_equal expected, actual
  end

  private

  def fake_app_with_lines
    @fake_app_with_lines ||= ::HelloWorld.new
  end
end
