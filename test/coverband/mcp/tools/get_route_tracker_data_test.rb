# frozen_string_literal: true

require File.expand_path("../../../test_helper", File.dirname(__FILE__))

begin
  require "coverband/mcp"
rescue LoadError
  puts "MCP gem not available, skipping MCP tools tests"
end

if defined?(Coverband::MCP)
  class GetRouteTrackerDataTest < Minitest::Test
    def setup
      super
      Coverband.configure do |config|
        config.store = Coverband::Adapters::RedisStore.new(Redis.new(db: 2))
        config.track_routes = true
      end
    end

    def teardown
      super
      Coverband.configuration.store.clear! if Coverband.configuration.store
      Coverband.configuration.track_routes = false
    end

    test "tool has correct metadata" do
      assert_equal "Get Route Tracker Data", Coverband::MCP::Tools::GetRouteTrackerData.title
      assert_includes Coverband::MCP::Tools::GetRouteTrackerData.description, "Rails route usage tracking"
    end

    test "input schema has optional show_unused_only parameter" do
      schema = Coverband::MCP::Tools::GetRouteTrackerData.input_schema
      assert_equal "object", schema[:type]
      assert schema[:required].nil? || schema[:required].empty?
      assert_equal "boolean", schema[:properties][:show_unused_only][:type]
    end

    test "call returns route tracking data when tracker is enabled" do
      tracker_mock = mock("route_tracker")
      tracker_mock.expects(:tracking_since).returns("2024-01-01").twice
      tracker_mock.expects(:as_json).returns({
        "used_keys" => ["GET /users", "POST /users", "GET /users/:id"],
        "unused_keys" => ["DELETE /users/:id", "PATCH /users/:id"]
      }.to_json)

      Coverband.configuration.expects(:route_tracker).returns(tracker_mock).twice

      response = Coverband::MCP::Tools::GetRouteTrackerData.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response
      refute response.is_error
      
      result = JSON.parse(response.content.first[:text])
      
      assert_equal "2024-01-01", result["tracking_since"]
      assert_equal 3, result["total_used"]
      assert_equal 2, result["total_unused"]
      assert_includes result["used_routes"], "GET /users"
      assert_includes result["unused_routes"], "DELETE /users/:id"
    end

    test "call returns only unused routes when show_unused_only is true" do
      tracker_mock = mock("route_tracker")
      tracker_mock.expects(:tracking_since).returns("2024-01-01")
      tracker_mock.expects(:as_json).returns({
        "unused_keys" => ["DELETE /users/:id", "PATCH /users/:id"]
      }.to_json)

      Coverband.configuration.expects(:route_tracker).returns(tracker_mock).twice

      response = Coverband::MCP::Tools::GetRouteTrackerData.call(
        show_unused_only: true,
        server_context: {}
      )

      result = JSON.parse(response.content.first[:text])
      
      assert_equal "2024-01-01", result["tracking_since"]
      assert_equal 2, result["total_unused"]
      assert_includes result["unused_routes"], "DELETE /users/:id"
      refute_includes result, "used_routes"
      refute_includes result, "total_used"
    end

    test "call returns message when route tracking is not enabled" do
      Coverband.configuration.expects(:route_tracker).returns(nil)

      response = Coverband::MCP::Tools::GetRouteTrackerData.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response
      refute response.is_error
      assert_includes response.content.first[:text], "Route tracking is not enabled"
      assert_includes response.content.first[:text], "config.track_routes = true"
    end

    test "call handles empty tracking data gracefully" do
      tracker_mock = mock("route_tracker")
      tracker_mock.expects(:tracking_since).returns("2024-01-01").twice
      tracker_mock.expects(:as_json).returns({
        "used_keys" => nil,
        "unused_keys" => nil
      }.to_json)

      Coverband.configuration.expects(:route_tracker).returns(tracker_mock).twice

      response = Coverband::MCP::Tools::GetRouteTrackerData.call(server_context: {})

      result = JSON.parse(response.content.first[:text])
      
      assert_equal 0, result["total_used"]
      assert_equal 0, result["total_unused"]
      assert_equal [], result["used_routes"]
      assert_equal [], result["unused_routes"]
    end

    test "call handles errors gracefully" do
      Coverband.configuration.expects(:route_tracker).raises(StandardError.new("Test error"))

      response = Coverband::MCP::Tools::GetRouteTrackerData.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response
      assert response.is_error
      assert_includes response.content.first[:text], "Error getting route tracker data: Test error"
    end
  end
end