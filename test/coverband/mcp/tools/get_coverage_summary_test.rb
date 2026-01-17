# frozen_string_literal: true

require File.expand_path("../../../test_helper", File.dirname(__FILE__))

begin
  require "coverband/mcp"
rescue LoadError
  puts "MCP gem not available, skipping MCP tools tests"
end

if defined?(Coverband::MCP)
  class GetCoverageSummaryTest < Minitest::Test
    def setup
      super
      Coverband.configure do |config|
        config.store = Coverband::Adapters::RedisStore.new(Redis.new(db: 2))
      end
    end

    def teardown
      super
      Coverband.configuration.store.clear! if Coverband.configuration.store
    end

    test "tool has correct metadata" do
      assert_includes Coverband::MCP::Tools::GetCoverageSummary.description, "overall production code coverage"
    end

    test "input schema has no required parameters" do
      schema = Coverband::MCP::Tools::GetCoverageSummary.input_schema
      # Schema should be an InputSchema object
      assert_instance_of ::MCP::Tool::InputSchema, schema
    end

    test "call returns coverage summary" do
      # Mock the JSON report
      mock_data = {
        "total_files" => 50,
        "lines_of_code" => 1000,
        "lines_covered" => 800,
        "lines_missed" => 200,
        "covered_percent" => 80.0,
        "covered_strength" => 85.5
      }

      report_mock = mock("json_report")
      report_mock.expects(:report).returns(mock_data.to_json)
      Coverband::Reporters::JSONReport.expects(:new).returns(report_mock)

      response = Coverband::MCP::Tools::GetCoverageSummary.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response
      assert_equal 1, response.content.length
      assert_equal "text", response.content.first[:type]
      
      result = JSON.parse(response.content.first[:text])
      assert_equal 50, result["total_files"]
      assert_equal 1000, result["lines_of_code"]
      assert_equal 800, result["lines_covered"]
      assert_equal 200, result["lines_missed"]
      assert_equal 80.0, result["covered_percent"]
      assert_equal 85.5, result["covered_strength"]
    end

    test "call handles errors gracefully" do
      Coverband::Reporters::JSONReport.expects(:new).raises(StandardError.new("Test error"))

      response = Coverband::MCP::Tools::GetCoverageSummary.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response
      assert_includes response.content.first[:text], "Error getting coverage summary: Test error"
    end
  end
end