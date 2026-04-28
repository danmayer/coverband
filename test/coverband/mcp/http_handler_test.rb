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

    test "handles MCP POST requests at /mcp endpoint via StreamableHTTPTransport" do
      # Mock the transport to verify it's called
      transport_mock = mock("transport")
      transport_mock.expects(:handle_request).returns([200, {"Content-Type" => "application/json"}, ["{}"]])

      handler = Coverband::MCP::HttpHandler.new
      handler.expects(:transport).returns(transport_mock)

      @app = handler

      json_request = {
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "id" => 1
      }.to_json

      post "/mcp", json_request, {"CONTENT_TYPE" => "application/json"}

      assert_equal 200, last_response.status
    end

    test "handles MCP GET requests at /mcp endpoint via StreamableHTTPTransport" do
      # Mock the transport to verify it's called for GET
      transport_mock = mock("transport")
      transport_mock.expects(:handle_request).returns([200, {"Content-Type" => "text/event-stream"}, []])

      handler = Coverband::MCP::HttpHandler.new
      handler.expects(:transport).returns(transport_mock)

      @app = handler

      get "/mcp", {}, {"ACCEPT" => "text/event-stream"}

      assert_equal 200, last_response.status
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

    test "responds to GET, POST, DELETE, OPTIONS for MCP endpoint" do
      transport_mock = mock("transport")
      transport_mock.expects(:handle_request).at_least(3).returns([200, {"Content-Type" => "application/json"}, ["{}"]])

      handler = Coverband::MCP::HttpHandler.new
      handler.expects(:transport).at_least(3).returns(transport_mock)

      @app = handler

      # POST request
      post "/mcp", "{}", {"CONTENT_TYPE" => "application/json"}
      assert_equal 200, last_response.status

      # GET request
      get "/mcp", {}, {"ACCEPT" => "text/event-stream"}
      assert_equal 200, last_response.status

      # DELETE request
      delete "/mcp"
      assert_equal 200, last_response.status
    end

    test "handles CORS preflight OPTIONS request" do
      handler = Coverband::MCP::HttpHandler.new
      @app = handler

      options "/mcp"

      assert_equal 204, last_response.status
      assert_equal "*", last_response.headers["Access-Control-Allow-Origin"]
      assert_equal "GET, POST, DELETE, OPTIONS", last_response.headers["Access-Control-Allow-Methods"]
    end

    test "delegates non-MCP requests to wrapped app for non-POST" do
      @app = app_with_wrapped_handler

      get "/other-path"
      assert_equal 200, last_response.status
      assert_equal "wrapped app response", last_response.body

      delete "/other-path"
      assert_equal 200, last_response.status
      assert_equal "wrapped app response", last_response.body
    end

    test "mcp_request? correctly identifies MCP requests" do
      handler = Coverband::MCP::HttpHandler.new

      # POST request to /mcp path
      env = Rack::MockRequest.env_for("/mcp", method: "POST")
      request = Rack::Request.new(env)
      assert handler.send(:mcp_request?, request)

      # GET request to /mcp
      env = Rack::MockRequest.env_for("/mcp", method: "GET")
      request = Rack::Request.new(env)
      assert handler.send(:mcp_request?, request)

      # DELETE request to /mcp
      env = Rack::MockRequest.env_for("/mcp", method: "DELETE")
      request = Rack::Request.new(env)
      assert handler.send(:mcp_request?, request)

      # OPTIONS request to /mcp
      env = Rack::MockRequest.env_for("/mcp", method: "OPTIONS")
      request = Rack::Request.new(env)
      assert handler.send(:mcp_request?, request)

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
