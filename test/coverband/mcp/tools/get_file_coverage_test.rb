# frozen_string_literal: true

require File.expand_path("../../../test_helper", File.dirname(__FILE__))

begin
  require "coverband/mcp"
rescue LoadError
  puts "MCP gem not available, skipping MCP tools tests"
end

if defined?(Coverband::MCP)
  class GetFileCoverageTest < Minitest::Test
    def setup
      super
      Coverband.configure do |config|
        config.store = Coverband::Adapters::RedisStore.new(Redis.new(db: 2))
        config.mcp_enabled = true  # Enable MCP for testing
      end
    end

    def teardown
      super
      Coverband.configuration.store&.clear!
    end

    test "tool has correct metadata" do
      assert_includes Coverband::MCP::Tools::GetFileCoverage.description, "line-by-line coverage data"
    end

    test "input schema requires filename parameter" do
      schema = Coverband::MCP::Tools::GetFileCoverage.input_schema
      assert_instance_of ::MCP::Tool::InputSchema, schema
    end

    test "call returns file coverage data when file exists" do
      filename = "app/models/user.rb"
      full_path = "/app/app/models/user.rb"

      mock_file_data = {
        "filename" => full_path,
        "covered_percent" => 85.0,
        "lines_of_code" => 100,
        "lines_covered" => 85,
        "lines_missed" => 15,
        "runtime_percentage" => 90.0,
        "never_loaded" => false,
        "coverage" => [1, 1, 0, 1, 1, nil, 1]
      }

      mock_data = {
        "files" => {
          full_path => mock_file_data
        }
      }

      report_mock = mock("json_report")
      report_mock.expects(:report).returns(mock_data.to_json)
      Coverband::Reporters::JSONReport.expects(:new).with(
        Coverband.configuration.store,
        {filename: filename, line_coverage: true}
      ).returns(report_mock)

      response = Coverband::MCP::Tools::GetFileCoverage.call(
        filename: filename,
        server_context: {}
      )

      assert_instance_of ::MCP::Tool::Response, response

      result = JSON.parse(response.content.first[:text])
      assert_includes result, full_path
      assert_equal 85.0, result[full_path]["covered_percent"]
      assert_equal 100, result[full_path]["lines_of_code"]
      assert_equal [1, 1, 0, 1, 1, nil, 1], result[full_path]["coverage"]
    end

    test "call returns message when no files found" do
      filename = "nonexistent.rb"

      mock_data = {"files" => nil}

      report_mock = mock("json_report")
      report_mock.expects(:report).returns(mock_data.to_json)
      Coverband::Reporters::JSONReport.expects(:new).returns(report_mock)

      response = Coverband::MCP::Tools::GetFileCoverage.call(
        filename: filename,
        server_context: {}
      )

      assert_instance_of ::MCP::Tool::Response, response
      assert_includes response.content.first[:text], "No coverage data found for file: nonexistent.rb"
    end

    test "call returns message when no matching files" do
      filename = "nonexistent.rb"

      mock_data = {
        "files" => {
          "/app/other/file.rb" => {"filename" => "/app/other/file.rb"}
        }
      }

      report_mock = mock("json_report")
      report_mock.expects(:report).returns(mock_data.to_json)
      Coverband::Reporters::JSONReport.expects(:new).returns(report_mock)

      response = Coverband::MCP::Tools::GetFileCoverage.call(
        filename: filename,
        server_context: {}
      )

      assert_instance_of ::MCP::Tool::Response, response
      assert_includes response.content.first[:text], "No coverage data found for file matching: nonexistent.rb"
    end

    test "call handles partial filename matches" do
      filename = "user"

      matching_files = {
        "/app/models/user.rb" => {"filename" => "/app/models/user.rb", "covered_percent" => 85.0},
        "/app/helpers/user_helper.rb" => {"filename" => "/app/helpers/user_helper.rb", "covered_percent" => 90.0}
      }

      mock_data = {
        "files" => matching_files.merge({
          "/app/models/order.rb" => {"filename" => "/app/models/order.rb", "covered_percent" => 75.0}
        })
      }

      report_mock = mock("json_report")
      report_mock.expects(:report).returns(mock_data.to_json)
      Coverband::Reporters::JSONReport.expects(:new).returns(report_mock)

      response = Coverband::MCP::Tools::GetFileCoverage.call(
        filename: filename,
        server_context: {}
      )

      result = JSON.parse(response.content.first[:text])
      assert_equal 2, result.keys.length
      assert_includes result, "/app/models/user.rb"
      assert_includes result, "/app/helpers/user_helper.rb"
      refute_includes result, "/app/models/order.rb"
    end

    test "call handles errors gracefully" do
      Coverband::Reporters::JSONReport.expects(:new).raises(StandardError.new("Test error"))

      response = Coverband::MCP::Tools::GetFileCoverage.call(
        filename: "test.rb",
        server_context: {}
      )

      assert_instance_of ::MCP::Tool::Response, response
      assert_includes response.content.first[:text], "Error getting file coverage: Test error"
    end
  end
end
