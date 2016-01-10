require File.expand_path('../test_helper', File.dirname(__FILE__))
require 'rack'

class MiddlewareTest < Test::Unit::TestCase

  test "call app" do
    request = Rack::MockRequest.env_for("/anything.json")
    Coverband::Base.instance.reset_instance
    middleware = Coverband::Middleware.new(fake_app)
    results = middleware.call(request)
    assert_equal "/anything.json", results.last
  end

  test 'pass all rack lint checks' do
    Coverband::Base.instance.reset_instance
    app = Rack::Lint.new(Coverband::Middleware.new(fake_app))
    env = Rack::MockRequest.env_for('/hello')
    app.call(env)
  end

  test 'always be enabled with sample percentage of 100' do
    request = Rack::MockRequest.env_for("/anything.json")
    Coverband::Base.instance.reset_instance
    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, Coverband::Base.instance.instance_variable_get("@enabled")
    Coverband::Base.instance.instance_variable_set("@sample_percentage", 100.0)
    results = middleware.call(request)
    assert_equal true, Coverband::Base.instance.instance_variable_get("@enabled")
  end

  test 'never be enabled with sample percentage of 0' do
    request = Rack::MockRequest.env_for("/anything.json")
    Coverband::Base.instance.reset_instance
    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, Coverband::Base.instance.instance_variable_get("@enabled")
    Coverband::Base.instance.instance_variable_set("@sample_percentage", 0.0)
    results = middleware.call(request)
    assert_equal false, Coverband::Base.instance.instance_variable_get("@enabled")
  end

  test 'always unset function when sampling' do
    request = Rack::MockRequest.env_for("/anything.json")
    Coverband::Base.instance.reset_instance
    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, Coverband::Base.instance.instance_variable_get("@tracer_set")
    Coverband::Base.instance.instance_variable_set("@sample_percentage", 100.0)
    results = middleware.call(request)
    assert_equal false, Coverband::Base.instance.instance_variable_get("@tracer_set")
  end

  test 'always unset function when not sampling' do
    request = Rack::MockRequest.env_for("/anything.json")
    Coverband::Base.instance.reset_instance
    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, Coverband::Base.instance.instance_variable_get("@tracer_set")
    middleware.instance_variable_set("@sample_percentage", 0.0)
    results = middleware.call(request)
    assert_equal false, Coverband::Base.instance.instance_variable_get("@tracer_set")
  end

  test 'always record coverage, set trace func, and add_files when sampling' do
    request = Rack::MockRequest.env_for("/anything.json")
    Coverband::Base.instance.reset_instance
    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, Coverband::Base.instance.instance_variable_get("@enabled")
    Coverband::Base.instance.instance_variable_set("@sample_percentage", 100.0)
    Coverband::Base.instance.expects(:add_file).at_least_once
    results = middleware.call(request)
    assert_equal true, Coverband::Base.instance.instance_variable_get("@enabled")
  end

  test 'always report coverage when sampling' do
    request = Rack::MockRequest.env_for("/anything.json")
    Coverband::Base.instance.reset_instance

    file_with_path = File.expand_path('../../lib/coverband/middleware.rb', File.dirname(__FILE__))

    middleware = Coverband::Middleware.new(fake_app)
    assert_equal false, Coverband::Base.instance.instance_variable_get("@enabled")
    Coverband::Base.instance.instance_variable_set("@sample_percentage", 100.0)
    fake_redis = Redis.new
    Coverband::Base.instance.instance_variable_set("@reporter", Coverband::RedisStore.new(fake_redis))
    fake_redis.stubs(:info).returns({'redis_version' => 3.0})
    fake_redis.expects(:sadd).at_least_once
    trace_point = Coverband::Base.instance.instance_variable_get(:@trace)
    line_numbers = trace_point ? [11,12] : [11, 11, 11, 12]
    fake_redis.expects(:sadd).at_least_once.with("coverband.#{file_with_path}", line_numbers)
    results = middleware.call(request)
    assert_equal true, Coverband::Base.instance.instance_variable_get("@enabled")
  end

  if defined? TracePoint
    test 'report only on calls when configured' do
      request = Rack::MockRequest.env_for("/anything.json")
      Coverband.configuration.trace_point_events = [:call]
      Coverband::Base.instance.reset_instance
      file_with_path = File.expand_path('../../lib/coverband/base.rb', File.dirname(__FILE__))
      middleware = Coverband::Middleware.new(fake_app)
      assert_equal false, Coverband::Base.instance.instance_variable_get("@enabled")
      Coverband::Base.instance.instance_variable_set("@sample_percentage", 100.0)
      fake_redis = Redis.new
      Coverband::Base.instance.instance_variable_set("@reporter", Coverband::RedisStore.new(fake_redis))
      fake_redis.stubs(:info).returns({'redis_version' => 3.0})
      fake_redis.expects(:sadd).at_least_once
      fake_redis.expects(:sadd).at_least_once.with("coverband.#{file_with_path}", [6, 84, 148])
      results = middleware.call(request)
      assert_equal true, Coverband::Base.instance.instance_variable_get("@enabled")
    end
  end



  private

  def fake_app
    @app ||= lambda { |env| [200, {'Content-Type' => 'text/plain'}, env['PATH_INFO']] }
  end

  def fake_app_with_lines
    @lines_app ||= ::HelloWorld.new
  end

end
