# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))
require File.expand_path('../fake_app/basic_rack', File.dirname(__FILE__))
require 'rack'

class MiddlewareTest < Test::Unit::TestCase
  BASE_KEY = Coverband::Adapters::RedisStore::BASE_KEY

  def setup
    Coverband.configure do |config|
      config.redis             = nil
      config.store             = nil
      config.collector         = 'trace'
      config.store             = Coverband::Adapters::RedisStore.new(Redis.new)
    end
  end

  test 'call app' do
    request = Rack::MockRequest.env_for('/anything.json')
    Coverband::Collectors::Base.instance.reset_instance
    middleware = Coverband::Middleware.new(fake_app)
    results = middleware.call(request)
    assert_equal '/anything.json', results.last
  end

  test 'pass all rack lint checks' do
    Coverband::Collectors::Base.instance.reset_instance
    app = Rack::Lint.new(Coverband::Middleware.new(fake_app))
    env = Rack::MockRequest.env_for('/hello')
    app.call(env)
  end

  test 'always be enabled with sample percentage of 100' do
    request = Rack::MockRequest.env_for('/anything.json')
    Coverband::Collectors::Base.instance.reset_instance
    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, Coverband::Collectors::Base.instance.instance_variable_get('@enabled')
    Coverband::Collectors::Base.instance.instance_variable_set('@sample_percentage', 100.0)
    middleware.call(request)
    assert_equal true, Coverband::Collectors::Base.instance.instance_variable_get('@enabled')
  end

  test 'never be enabled with sample percentage of 0' do
    request = Rack::MockRequest.env_for('/anything.json')
    Coverband::Collectors::Base.instance.reset_instance
    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, Coverband::Collectors::Base.instance.instance_variable_get('@enabled')
    Coverband::Collectors::Base.instance.instance_variable_set('@sample_percentage', 0.0)
    middleware.call(request)
    assert_equal false, Coverband::Collectors::Base.instance.instance_variable_get('@enabled')
  end

  test 'always record coverage, set trace func, and add_files when sampling' do
    request = Rack::MockRequest.env_for('/anything.json')
    Coverband::Collectors::Base.instance.reset_instance
    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, Coverband::Collectors::Base.instance.instance_variable_get('@enabled')
    Coverband::Collectors::Base.instance.instance_variable_set('@sample_percentage', 100.0)
    middleware.call(request)
    assert_equal true, Coverband::Collectors::Base.instance.instance_variable_get('@enabled')
  end

  test 'reports coverage when an error is raised' do
    request = Rack::MockRequest.env_for('/anything.json')
    Coverband::Collectors::Base.instance.reset_instance
    Coverband::Collectors::Base.instance.expects(:report_coverage).once
    middleware = Coverband::Middleware.new(fake_app_raise_error)
    begin
      middleware.call(request)
    rescue StandardError
      nil
    end
  end

  test 'always report coverage when sampling' do
    request = Rack::MockRequest.env_for('/anything.json')
    Coverband::Collectors::Base.instance.reset_instance
    middleware = Coverband::Middleware.new(fake_app_with_lines)
    assert_equal false, Coverband::Collectors::Base.instance.instance_variable_get('@enabled')
    Coverband::Collectors::Base.instance.instance_variable_set('@sample_percentage', 100.0)
    fake_redis = Redis.new
    redis_store = Coverband::Adapters::RedisStore.new(fake_redis)
    redis_store.clear!
    Coverband::Collectors::Base.instance.reset_instance
    Coverband::Collectors::Base.instance.instance_variable_set('@store', redis_store)
    fake_redis.expects(:sadd).at_least_once
    fake_redis.expects(:mapped_hmset).at_least_once
    fake_redis.expects(:mapped_hmset).at_least_once.with("#{BASE_KEY}.#{basic_rack_ruby_file}", '7' => 1)
    middleware.call(request)
    assert_equal true, Coverband::Collectors::Base.instance.instance_variable_get('@enabled')
  end

  private

  def fake_app
    @fake_app ||= ->(env) { [200, { 'Content-Type' => 'text/plain' }, env['PATH_INFO']] }
  end

  def fake_app_raise_error
    @fake_app_raise_error ||= -> { raise 'sh** happens' }
  end

  def fake_app_with_lines
    @fake_app_with_lines ||= ::HelloWorld.new
  end

  def basic_rack_ruby_file
    File.expand_path('../fake_app/basic_rack.rb', File.dirname(__FILE__))
  end
end
