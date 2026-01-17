# frozen_string_literal: true

require File.expand_path("../../../test_helper", File.dirname(__FILE__))

begin
  require "coverband/mcp"
rescue LoadError
  puts "MCP gem not available, skipping MCP tools tests"
end

if defined?(Coverband::MCP)
  class GetTranslationTrackerDataTest < Minitest::Test
    def setup
      super
      Coverband.configure do |config|
        config.store = Coverband::Adapters::RedisStore.new(Redis.new(db: 2))
        config.track_translations = true
      end
    end

    def teardown
      super
      Coverband.configuration.store&.clear!
      Coverband.configuration.track_translations = false
    end

    test "tool has correct metadata" do
      assert_includes Coverband::MCP::Tools::GetTranslationTrackerData.description, "I18n translation key usage"
    end

    test "input schema has optional show_unused_only parameter" do
      schema = Coverband::MCP::Tools::GetTranslationTrackerData.input_schema
      assert_instance_of ::MCP::Tool::InputSchema, schema
    end

    test "call returns translation tracking data when tracker is enabled" do
      tracker_mock = mock("translation_tracker")
      tracker_mock.expects(:tracking_since).returns("2024-01-01")
      tracker_mock.expects(:as_json).returns({
        "used_keys" => ["user.name", "user.email", "errors.required"],
        "unused_keys" => ["admin.dashboard", "legacy.message"]
      }.to_json)

      Coverband.configuration.expects(:translations_tracker).returns(tracker_mock)

      response = Coverband::MCP::Tools::GetTranslationTrackerData.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response

      result = JSON.parse(response.content.first[:text])

      assert_equal "2024-01-01", result["tracking_since"]
      assert_equal 3, result["total_used"]
      assert_equal 2, result["total_unused"]
      assert_includes result["used_translations"], "user.name"
      assert_includes result["unused_translations"], "admin.dashboard"
    end

    test "call returns only unused translations when show_unused_only is true" do
      tracker_mock = mock("translation_tracker")
      tracker_mock.expects(:tracking_since).returns("2024-01-01")
      tracker_mock.expects(:as_json).returns({
        "unused_keys" => ["admin.dashboard", "legacy.message"]
      }.to_json)

      Coverband.configuration.expects(:translations_tracker).returns(tracker_mock)

      response = Coverband::MCP::Tools::GetTranslationTrackerData.call(
        show_unused_only: true,
        server_context: {}
      )

      result = JSON.parse(response.content.first[:text])

      assert_equal "2024-01-01", result["tracking_since"]
      assert_equal 2, result["total_unused"]
      assert_includes result["unused_translations"], "admin.dashboard"
      refute_includes result, "used_translations"
      refute_includes result, "total_used"
    end

    test "call returns message when translation tracking is not enabled" do
      Coverband.configuration.expects(:translations_tracker).returns(nil)

      response = Coverband::MCP::Tools::GetTranslationTrackerData.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response
      assert_includes response.content.first[:text], "Translation tracking is not enabled"
      assert_includes response.content.first[:text], "config.track_translations = true"
    end

    test "call handles empty tracking data gracefully" do
      tracker_mock = mock("translation_tracker")
      tracker_mock.expects(:tracking_since).returns("2024-01-01")
      tracker_mock.expects(:as_json).returns({
        "used_keys" => nil,
        "unused_keys" => nil
      }.to_json)

      Coverband.configuration.expects(:translations_tracker).returns(tracker_mock)

      response = Coverband::MCP::Tools::GetTranslationTrackerData.call(server_context: {})

      result = JSON.parse(response.content.first[:text])

      assert_equal 0, result["total_used"]
      assert_equal 0, result["total_unused"]
      assert_equal [], result["used_translations"]
      assert_equal [], result["unused_translations"]
    end

    test "call handles errors gracefully" do
      Coverband.configuration.expects(:translations_tracker).raises(StandardError.new("Test error"))

      response = Coverband::MCP::Tools::GetTranslationTrackerData.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response
      assert_includes response.content.first[:text], "Error getting translation tracker data: Test error"
    end
  end
end
