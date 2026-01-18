# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "rack/test"

begin
  require "coverband/mcp"
rescue LoadError
  puts "MCP gem not available, skipping MCP HTTP handler tests"
end

if defined?(Coverband::MCP)
  class MCPHttpHandlerTest < Minitest::Test
    include Rack::Test::Methods

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

    def app
      @app ||= Coverband::MCP::HttpHandler.new
    end

    def app_with_wrapped_handler
      @wrapped_app ||= begin
        mock_app = lambda { |env| [200, {"Content-Type" => "text/plain"}, ["wrapped app response"]] }
        Coverband::MCP::HttpHandler.new(mock_app)
      end
    end

    test "handles MCP requests at /mcp endpoint" do
      # Mock the server to return a simple response
      server_mock = mock("server")
      server_mock.expects(:handle_json).returns({"result" => "success"})

      handler = Coverband::MCP::HttpHandler.new
      handler.expects(:mcp_server).returns(server_mock)

      @app = handler

      json_request = {
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "id" => 1
      }.to_json

      post "/mcp", json_request, {"CONTENT_TYPE" => "application/json"}

      assert_equal 200, last_response.status
      assert_equal "application/json", last_response.content_type

      # Check CORS headers
      assert_equal "*", last_response.headers["Access-Control-Allow-Origin"]
      assert_equal "POST, OPTIONS", last_response.headers["Access-Control-Allow-Methods"]
      assert_equal "Content-Type", last_response.headers["Access-Control-Allow-Headers"]
    end

    test "returns 404 for non-MCP requests when no wrapped app" do
      get "/other-path"

      assert_equal 404, last_response.status
      assert_equal "text/plain", last_response.content_type
      assert_equal "Not Found", last_response.body
    end

    test "delegates non-MCP requests to wrapped app" do
      @app = app_with_wrapped_handler

      get "/other-path"

      assert_equal 200, last_response.status
      assert_equal "wrapped app response", last_response.body
    end

    test "only responds to POST requests for MCP endpoint" do
      get "/mcp"

      assert_equal 404, last_response.status
    end

    test "handles invalid JSON gracefully" do
      post "/mcp", "invalid json", {"CONTENT_TYPE" => "application/json"}

      assert_equal 400, last_response.status
      assert_equal "application/json", last_response.content_type

      response = JSON.parse(last_response.body)
      assert_includes response["error"], "Invalid JSON"
    end

    test "handles server errors gracefully" do
      # Mock server to raise an error
      server_mock = mock("server")
      server_mock.expects(:handle_json).raises(StandardError.new("Test error"))

      handler = Coverband::MCP::HttpHandler.new
      handler.expects(:mcp_server).returns(server_mock)

      @app = handler

      json_request = {"test" => "request"}.to_json
      post "/mcp", json_request, {"CONTENT_TYPE" => "application/json"}

      assert_equal 500, last_response.status

      response = JSON.parse(last_response.body)
      assert_includes response["error"], "Server error: Test error"
    end

    test "mcp_server is lazily initialized" do
      handler = Coverband::MCP::HttpHandler.new

      # First call creates the server
      server1 = handler.send(:mcp_server)
      assert_instance_of Coverband::MCP::Server, server1

      # Second call returns the same instance
      server2 = handler.send(:mcp_server)
      assert_same server1, server2
    end

    test "mcp_request? correctly identifies MCP requests" do
      handler = Coverband::MCP::HttpHandler.new

      # POST request to /mcp path
      env = Rack::MockRequest.env_for("/mcp", method: "POST")
      request = Rack::Request.new(env)
      assert handler.send(:mcp_request?, request)

      # POST request to /some-path/mcp (ends with /mcp)
      env = Rack::MockRequest.env_for("/some-path/mcp", method: "POST")
      request = Rack::Request.new(env)
      assert handler.send(:mcp_request?, request)

      # GET request to /mcp
      env = Rack::MockRequest.env_for("/mcp", method: "GET")
      request = Rack::Request.new(env)
      refute handler.send(:mcp_request?, request)

      # POST request to /other-path
      env = Rack::MockRequest.env_for("/other-path", method: "POST")
      request = Rack::Request.new(env)
      refute handler.send(:mcp_request?, request)
    end

    test "constant MCP_PATH is defined" do
      assert_equal "/mcp", Coverband::MCP::HttpHandler::MCP_PATH
    end
  end
end
