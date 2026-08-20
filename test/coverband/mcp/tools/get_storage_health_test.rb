# frozen_string_literal: true

require File.expand_path("../../../test_helper", File.dirname(__FILE__))

begin
  require "coverband/mcp"
rescue LoadError
  puts "MCP gem not available, skipping MCP tools tests"
end

if defined?(Coverband::MCP)
  class GetStorageHealthTest < Minitest::Test
    test "tool explains that diagnostics are observed state" do
      description = Coverband::MCP::Tools::GetStorageHealth.description

      assert_includes description, "observed"
      assert_includes description, "not an active backend probe"
    end

    test "tool returns the public storage health representation" do
      health = {
        coverage: {status: "stalled", data_loss: nil, unwritten: {deltas: 2, since: "2026-08-19T12:00:00Z"}},
        trackers: {}
      }
      Coverband.expects(:storage_health).returns(health)

      response = Coverband::MCP::Tools::GetStorageHealth.call(server_context: {})

      assert_instance_of ::MCP::Tool::Response, response
      assert_equal JSON.parse(JSON.generate(health)), JSON.parse(response.content.first[:text])
    end

    test "tool returns a formatted error response" do
      Coverband.expects(:storage_health).raises(StandardError.new("broken diagnostics"))

      response = Coverband::MCP::Tools::GetStorageHealth.call(server_context: {})

      assert_includes response.content.first[:text], "Error getting storage health: broken diagnostics"
    end
  end
end
