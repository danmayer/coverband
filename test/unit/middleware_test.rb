require File.expand_path('../test_helper', File.dirname(__FILE__))
require 'rack'
FAKE_RACK_APP_PATH = File.expand_path('../fake_app/basic_rack.rb', File.dirname(__FILE__))
require FAKE_RACK_APP_PATH

class MiddlewareTest < Test::Unit::TestCase
  
  should "call app" do
    request = Rack::MockRequest.env_for("/anything.json")
    middleware = Coverband::Middleware.new(fake_app)
    results = middleware.call(request)
    assert_equal "/anything.json", results.last
  end

  should 'pass all rack lint checks' do
    app = Rack::Lint.new(Coverband::Middleware.new(fake_app))
    env = Rack::MockRequest.env_for('/hello')
    app.call(env)
  end

  should 'always be enabled with sample percentage of 100' do
    request = Rack::MockRequest.env_for("/anything.json")
    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, middleware.instance_variable_get("@enabled")
    middleware.instance_variable_set("@sample_percentage", 100.0)
    results = middleware.call(request)
    assert_equal true, middleware.instance_variable_get("@enabled")
  end

  should 'never be enabled with sample percentage of 0' do
    request = Rack::MockRequest.env_for("/anything.json")
    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, middleware.instance_variable_get("@enabled")
    middleware.instance_variable_set("@sample_percentage", 0.0)
    results = middleware.call(request)
    assert_equal false, middleware.instance_variable_get("@enabled")
  end

  should 'always unset function when sampling' do
    request = Rack::MockRequest.env_for("/anything.json")
    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, middleware.instance_variable_get("@tracer_set")
    middleware.instance_variable_set("@sample_percentage", 100.0)
    results = middleware.call(request)
    assert_equal false, middleware.instance_variable_get("@tracer_set")
  end

  should 'always unset function when not sampling' do
    request = Rack::MockRequest.env_for("/anything.json")
    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, middleware.instance_variable_get("@tracer_set")
    middleware.instance_variable_set("@sample_percentage", 0.0)
    results = middleware.call(request)
    assert_equal false, middleware.instance_variable_get("@tracer_set")
  end

  should 'always record coverage, set trace func, and add_files when sampling' do
    request = Rack::MockRequest.env_for("/anything.json")
    middleware = Coverband::Middleware.new(fake_app_with_lines)
    assert_equal false, middleware.instance_variable_get("@enabled")
    middleware.instance_variable_set("@sample_percentage", 100.0)
    middleware.expects(:add_file).at_least_once
    results = middleware.call(request)
    assert_equal true, middleware.instance_variable_get("@enabled")
  end

  should 'always report coverage when sampling' do
    request = Rack::MockRequest.env_for("/anything.json")
    middleware = Coverband::Middleware.new(fake_app_with_lines)
    assert_equal false, middleware.instance_variable_get("@enabled")
    middleware.instance_variable_set("@sample_percentage", 100.0)
    fake_redis = Redis.new
    middleware.instance_variable_set("@reporter", Coverband::RedisStore.new(fake_redis))
    fake_redis.stubs(:info).returns({'redis_version' => 3.0})
    fake_redis.expects(:sadd).at_least_once
    fake_redis.expects(:sadd).at_least_once.with("coverband.#{FAKE_RACK_APP_PATH}", [4,5,6])
    results = middleware.call(request)
    assert_equal true, middleware.instance_variable_get("@enabled")
  end

  private

  def fake_app
    @app ||= lambda { |env| [200, {'Content-Type' => 'text/plain'}, env['PATH_INFO']] }
  end

  def fake_app_with_lines
    @lines_app ||= ::HelloWorld.new
  end

end
