# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "coverband/integrations/report_middleware"

class ReportMiddlewareTest < Minitest::Test
  def setup
    super
    Coverband.configure do |config|
      config.background_reporting_enabled = false
    end
  end

  test "reports coverage" do
    request = Rack::MockRequest.env_for("/anything.json")
    Coverband::Collectors::Coverage.instance.expects(:report_coverage)
    middleware = Coverband::ReportMiddleware.new(fake_app)
    middleware.call(request)
  end

  test "reports coverage when an error is raised" do
    request = Rack::MockRequest.env_for("/anything.json")
    Coverband::Collectors::Coverage.instance.reset_instance
    Coverband::Collectors::Coverage.instance.expects(:report_coverage).once
    middleware = Coverband::ReportMiddleware.new(fake_app_raise_error)
    begin
      middleware.call(request)
    rescue
      nil
    end
  end

  private

  def fake_app
    @fake_app ||= lambda do |env|
      [200, {"Content-Type" => "text/plain"}, env["PATH_INFO"]]
    end
  end

  def fake_app_raise_error
    @fake_app_raise_error ||= -> { raise "hell" }
  end
end
