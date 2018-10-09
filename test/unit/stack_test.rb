# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))
require 'rack'

class StackTest < Test::Unit::TestCase
  BASE_KEY = Coverband::Adapters::RedisStore::BASE_KEY
  TEST_RACK_APP = '../fake_app/basic_rack.rb'.freeze

  def setup
    Coverband.configure do |config|
      config.reporting_frequency = 100.0
      config.store = Coverband::Adapters::RedisStore.new(Redis.new)
    end
    Coverband.configuration.store.clear!
    #Coverband::Collectors::Base.instance.record_coverage
    @rack_file = File.expand_path(TEST_RACK_APP, File.dirname(__FILE__))
    require @rack_file
  end

  test 'call app' do
    request = Rack::MockRequest.env_for('/anything.json')
    middleware = Coverband::Middleware.new(fake_app_with_lines)
    results = middleware.call(request)
    assert_equal 'Hello Rack!', results.last
    expected = {"3"=>"1", "5"=>"1", "6"=>"1", "7"=>"1"}
    assert_equal expected, Coverband.configuration.store.coverage[@rack_file]

    # additional calls increase count by 1
    middleware.call(request)
    expected = {"3"=>"1", "5"=>"1", "6"=>"1", "7"=>"2"}
    assert_equal expected, Coverband.configuration.store.coverage[@rack_file]
  end

  private

  def fake_app_with_lines
    @fake_app_with_lines ||= ::HelloWorld.new
  end
end
