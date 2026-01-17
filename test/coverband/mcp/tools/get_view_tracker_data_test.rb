# frozen_string_literal: true

require File.expand_path("../../../test_helper", File.dirname(__FILE__))

begin
  require "coverband/mcp"
rescue LoadError
  puts "MCP gem not available, skipping MCP tools tests"
end

if defined?(Coverband::MCP)
  class GetViewTrackerDataTest < Minitest::Test
    def setup
      super
      Coverband.configure do |config|
        config.store = Coverband::Adapters::RedisStore.new(Redis.new(db: 2))
        config.track_views = true
        config.mcp_enabled = true  # Enable MCP for testing
      end
    end

    def teardown
      super
      Coverband.configuration.store&.clear!
      Coverband.configuration.track_views = false
    end

    test "tool has correct metadata" do
      assert_includes Coverband::MCP::Tools::GetViewTrackerData.description, "Rails view template usage"
    end

    test "input schema has optional show_unused_only parameter" do
      schema = Coverband::MCP::Tools::GetViewTrackerData.input_schema
      assert_instance_of ::MCP::Tool::InputSchema, schema
    end

    test "call returns view tracking data when tracker is enabled" do
      tracker_mock = mock("view_tracker")
      tracker_mock.expects(:tracking_since).returns("2024-01-01")
      tracker_mock.expects(:as_json).returns({
        "used_keys" => ["app/views/users/index.html.erb", "app/views/users/show.html.erb"],
        "unused_keys" => ["app/views/users/new.html.erb", "app/views/users/edit.html.erb"]
      }.to_json)

      Coverband.configuration.expects(:view_tracker).returns(tracker_mock)

      response = Coverband::MCP::Tools::GetViewTrackerData.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response

      result = JSON.parse(response.content.first[:text])

      assert_equal "2024-01-01", result["tracking_since"]
      assert_equal 2, result["total_used"]
      assert_equal 2, result["total_unused"]
      assert_includes result["used_views"], "app/views/users/index.html.erb"
      assert_includes result["unused_views"], "app/views/users/edit.html.erb"
    end

    test "call returns only unused views when show_unused_only is true" do
      tracker_mock = mock("view_tracker")
      tracker_mock.expects(:tracking_since).returns("2024-01-01")
      tracker_mock.expects(:as_json).returns({
        "unused_keys" => ["app/views/users/edit.html.erb", "app/views/orders/index.html.erb"]
      }.to_json)

      Coverband.configuration.expects(:view_tracker).returns(tracker_mock)

      response = Coverband::MCP::Tools::GetViewTrackerData.call(
        show_unused_only: true,
        server_context: {}
      )

      result = JSON.parse(response.content.first[:text])

      assert_equal "2024-01-01", result["tracking_since"]
      assert_equal 2, result["total_unused"]
      assert_includes result["unused_views"], "app/views/users/edit.html.erb"
      refute_includes result, "used_views"
      refute_includes result, "total_used"
    end

    test "call returns message when view tracking is not enabled" do
      Coverband.configuration.expects(:view_tracker).returns(nil)

      response = Coverband::MCP::Tools::GetViewTrackerData.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response
      assert_includes response.content.first[:text], "View tracking is not enabled"
      assert_includes response.content.first[:text], "config.track_views = true"
    end

    test "call handles empty tracking data gracefully" do
      tracker_mock = mock("view_tracker")
      tracker_mock.expects(:tracking_since).returns("2024-01-01")
      tracker_mock.expects(:as_json).returns({
        "used_keys" => nil,
        "unused_keys" => nil
      }.to_json)

      Coverband.configuration.expects(:view_tracker).returns(tracker_mock)

      response = Coverband::MCP::Tools::GetViewTrackerData.call(server_context: {})

      result = JSON.parse(response.content.first[:text])

      assert_equal 0, result["total_used"]
      assert_equal 0, result["total_unused"]
      assert_equal [], result["used_views"]
      assert_equal [], result["unused_views"]
    end

    test "call handles errors gracefully" do
      Coverband.configuration.expects(:view_tracker).raises(StandardError.new("Test error"))

      response = Coverband::MCP::Tools::GetViewTrackerData.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response
      assert_includes response.content.first[:text], "Error getting view tracker data: Test error"
    end
  end
end
