# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

begin
  require "coverband/mcp"
rescue LoadError
  puts "MCP gem not available, skipping MCP tests"
end

if defined?(Coverband::MCP)
  class MCPServerTest < Minitest::Test
    def setup
      super
      Coverband.configure do |config|
        config.store = Coverband::Adapters::RedisStore.new(Redis.new(db: 2))
        config.mcp_enabled = true  # Enable MCP for testing
      end
      @server = Coverband::MCP::Server.new
    end

    def teardown
      super
      Coverband.configuration.store&.clear!
    end

    test "server initializes with correct attributes" do
      assert_equal "coverband", @server.mcp_server.name
      assert_equal Coverband::VERSION, @server.mcp_server.version
      assert_includes @server.mcp_server.instructions, "Coverband production code coverage"
      refute_empty @server.mcp_server.tools
    end

    test "server has all expected tools registered" do
      tool_names = @server.mcp_server.tools.keys
      expected_tools = [
        "get_coverage_summary",
        "get_file_coverage",
        "get_uncovered_files",
        "get_dead_methods",
        "get_view_tracker_data",
        "get_route_tracker_data",
        "get_translation_tracker_data"
      ]

      expected_tools.each do |tool_name|
        assert_includes tool_names, tool_name, "Expected tool #{tool_name} to be registered"
      end
    end

    test "server configures Coverband if not already configured" do
      # Reset configuration
      Coverband.instance_variable_set(:@configuration, nil)

      # Enable MCP for the new configuration
      Coverband.configure do |config|
        config.mcp_enabled = true
      end

      # Creating server should auto-configure
      Coverband::MCP::Server.new

      assert Coverband.configured?, "Coverband should be auto-configured"
    end

    test "run_stdio creates and opens stdio transport" do
      transport_mock = mock("stdio_transport")
      transport_mock.expects(:open).once

      ::MCP::Server::Transports::StdioTransport.expects(:new).with(@server.mcp_server).returns(transport_mock)

      @server.run_stdio
    end

    test "run_http starts server with correct configuration" do
      # Mock the handler - stub the handler lookup method that exists
      handler_mock = mock("handler")
      handler_mock.expects(:run).once

      # Just stub the method on the server itself to avoid version dependencies
      @server.expects(:puts).at_least_once # For the info output

      # Mock Rack handler differently to avoid version issues
      require "rack"
      if defined?(Rackup) && Rackup.respond_to?(:server)
        Rackup.expects(:server).with("puma").returns(handler_mock)
      else
        # Skip this test if we can't properly mock the handler
        skip "Unable to mock Rack handler in this environment"
      end

      @server.run_http(port: 9999, host: "test.local")
    end

    test "handle_json delegates to mcp_server" do
      json_request = {"method" => "test"}
      expected_response = {"result" => "success"}

      @server.mcp_server.expects(:handle_json).with(json_request).returns(expected_response)

      result = @server.handle_json(json_request)
      assert_equal expected_response, result
    end

    test "create_rack_app returns functioning rack application" do
      transport = mock("transport")
      app = @server.send(:create_rack_app, transport)

      assert_respond_to app, :call

      # Test request handling - just verify the transport is called
      env = {"REQUEST_METHOD" => "POST", "PATH_INFO" => "/"}
      transport.expects(:handle_request).with(kind_of(Rack::Request)).returns([200, {}, ["response"]])

      response = app.call(env)

      # Just check status and that we got a response (middleware may wrap body)
      assert_equal 200, response[0]
    end

    test "default http port is 9023" do
      assert_equal 9023, Coverband::MCP::Server::DEFAULT_HTTP_PORT
    end
  end
end
