# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "rack"

class BackgroundMiddlewareTest < Minitest::Test
  def setup
    super
    Coverband.configure do |config|
      config.background_reporting_enabled = false
    end
  end

  test "call app" do
    request = Rack::MockRequest.env_for("/anything.json")
    Coverband::Collectors::Coverage.instance.reset_instance
    middleware = Coverband::BackgroundMiddleware.new(fake_app)
    results = middleware.call(request)
    assert_equal "/anything.json", results.last
  end

  test "pass all rack lint checks" do
    Coverband::Collectors::Coverage.instance.reset_instance
    app = Rack::Lint.new(Coverband::BackgroundMiddleware.new(fake_app))
    env = Rack::MockRequest.env_for("/hello")
    app.call(env)
  end

  test "starts background reporter when configured" do
    request = Rack::MockRequest.env_for("/anything.json")
    Coverband.configuration.stubs(:background_reporting_enabled).returns(true)
    Coverband::Background.expects(:start)
    middleware = Coverband::BackgroundMiddleware.new(fake_app)
    middleware.call(request)
  end

  private

  def fake_app
    @fake_app ||= lambda do |env|
      [200, {"content-type" => "text/plain"}, env["PATH_INFO"]]
    end
  end
end
