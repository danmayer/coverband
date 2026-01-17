# frozen_string_literal: true

require File.expand_path("../../../test_helper", File.dirname(__FILE__))

begin
  require "coverband/mcp"
rescue LoadError
  puts "MCP gem not available, skipping MCP tools tests"
end

if defined?(Coverband::MCP)
  class GetUncoveredFilesTest < Minitest::Test
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
      assert_includes Coverband::MCP::Tools::GetUncoveredFiles.description, "coverage below a specified threshold"
    end

    test "input schema has optional parameters" do
      schema = Coverband::MCP::Tools::GetUncoveredFiles.input_schema
      assert_instance_of ::MCP::Tool::InputSchema, schema
    end

    test "call returns uncovered files below threshold" do
      mock_files = {
        "/app/models/user.rb" => {"covered_percent" => 30.0, "never_loaded" => false},
        "/app/models/order.rb" => {"covered_percent" => 80.0, "never_loaded" => false},
        "/app/helpers/helper.rb" => {"covered_percent" => 20.0, "never_loaded" => false},
        "/app/unused.rb" => {"covered_percent" => 0, "never_loaded" => true}
      }

      mock_data = {"files" => mock_files}

      report_mock = mock("json_report")
      report_mock.expects(:report).returns(mock_data.to_json)
      Coverband::Reporters::JSONReport.expects(:new).with(
        Coverband.configuration.store,
        line_coverage: false
      ).returns(report_mock)

      response = Coverband::MCP::Tools::GetUncoveredFiles.call(
        threshold: 50,
        server_context: {}
      )

      assert_instance_of ::MCP::Tool::Response, response

      result = JSON.parse(response.content.first[:text])

      # Should include files below 50% and never loaded files
      expected_files = ["/app/helpers/helper.rb", "/app/models/user.rb", "/app/unused.rb"]
      actual_files = result["files"].map { |file| file["file"] }

      assert_equal 3, result["files"].length
      expected_files.each do |file|
        assert_includes actual_files, file
      end

      # Should be sorted by coverage percentage (ascending)
      coverages = result["files"].map { |file| file["covered_percent"] || 0 }
      assert_equal coverages.sort, coverages
    end

    test "call excludes never loaded files when include_never_loaded is false" do
      mock_files = {
        "/app/models/user.rb" => {"covered_percent" => 30.0, "never_loaded" => false},
        "/app/unused.rb" => {"covered_percent" => 0, "never_loaded" => true}
      }

      mock_data = {"files" => mock_files}

      report_mock = mock("json_report")
      report_mock.expects(:report).returns(mock_data.to_json)
      Coverband::Reporters::JSONReport.expects(:new).returns(report_mock)

      response = Coverband::MCP::Tools::GetUncoveredFiles.call(
        threshold: 50,
        include_never_loaded: false,
        server_context: {}
      )

      result = JSON.parse(response.content.first[:text])

      # Should only include user.rb (below threshold but not never_loaded)
      assert_equal 1, result["files"].length
      assert_equal "/app/models/user.rb", result["files"].first["file"]
      assert_equal 30.0, result["files"].first["covered_percent"]
    end

    test "call uses default values when parameters not provided" do
      mock_files = {
        "/app/models/user.rb" => {"covered_percent" => 40.0, "never_loaded" => false},
        "/app/models/order.rb" => {"covered_percent" => 60.0, "never_loaded" => false}
      }

      mock_data = {"files" => mock_files}

      report_mock = mock("json_report")
      report_mock.expects(:report).returns(mock_data.to_json)
      Coverband::Reporters::JSONReport.expects(:new).returns(report_mock)

      response = Coverband::MCP::Tools::GetUncoveredFiles.call(server_context: {})

      result = JSON.parse(response.content.first[:text])

      # Default threshold is 50, so should only include user.rb (40%)
      assert_equal 1, result["files"].length
      assert_equal "/app/models/user.rb", result["files"].first["file"]
    end

    test "call handles files with nil covered_percent" do
      mock_files = {
        "/app/models/user.rb" => {"covered_percent" => nil, "never_loaded" => false},
        "/app/models/order.rb" => {"covered_percent" => 60.0, "never_loaded" => false}
      }

      mock_data = {"files" => mock_files}

      report_mock = mock("json_report")
      report_mock.expects(:report).returns(mock_data.to_json)
      Coverband::Reporters::JSONReport.expects(:new).returns(report_mock)

      response = Coverband::MCP::Tools::GetUncoveredFiles.call(
        threshold: 50,
        server_context: {}
      )

      result = JSON.parse(response.content.first[:text])

      # File with nil coverage should be included (treated as 0)
      assert_equal 1, result["files"].length
      assert_equal "/app/models/user.rb", result["files"].first["file"]
      assert_nil result["files"].first["covered_percent"]
    end

    test "call returns empty array when no files below threshold" do
      mock_files = {
        "/app/models/user.rb" => {"covered_percent" => 80.0, "never_loaded" => false},
        "/app/models/order.rb" => {"covered_percent" => 90.0, "never_loaded" => false}
      }

      mock_data = {"files" => mock_files}

      report_mock = mock("json_report")
      report_mock.expects(:report).returns(mock_data.to_json)
      Coverband::Reporters::JSONReport.expects(:new).returns(report_mock)

      response = Coverband::MCP::Tools::GetUncoveredFiles.call(
        threshold: 50,
        server_context: {}
      )

      result = JSON.parse(response.content.first[:text])
      assert_equal 0, result["files"].length
    end

    test "call handles errors gracefully" do
      Coverband::Reporters::JSONReport.expects(:new).raises(StandardError.new("Test error"))

      response = Coverband::MCP::Tools::GetUncoveredFiles.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response
      assert_includes response.content.first[:text], "Error getting uncovered files: Test error"
    end
  end
end
