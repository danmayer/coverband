# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

begin
  require "coverband/mcp"
rescue LoadError
  puts "MCP gem not available, skipping MCP security tests"
end

if defined?(Coverband::MCP)
  class MCPSecurityTest < Minitest::Test
    def setup
      super
      # Don't enable MCP by default - we want to test security
      Coverband.configure do |config|
        config.store = Coverband::Adapters::RedisStore.new(Redis.new(db: 2))
      end
    end

    def teardown
      super
      Coverband.configuration.store&.clear!
    end

    test "MCP is disabled by default" do
      refute Coverband.configuration.mcp_enabled?, "MCP should be disabled by default"
    end

    test "cannot create MCP server when disabled" do
      error = assert_raises(SecurityError) do
        Coverband::MCP::Server.new
      end

      assert_includes error.message, "MCP is not enabled"
      assert_includes error.message, "config.mcp_enabled = true"
    end

    test "MCP can be enabled for allowed environments" do
      # Test environment should be allowed by default
      Coverband.configuration.mcp_enabled = true

      assert Coverband.configuration.mcp_enabled?, "MCP should be enabled when explicitly set"

      # Should be able to create server now
      server = Coverband::MCP::Server.new
      refute_nil server
    end

    test "environment restrictions work correctly" do
      Coverband.configuration.mcp_enabled = true

      # Temporarily override environment detection
      original_env_var = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "production"

      begin
        refute Coverband.configuration.mcp_enabled?,
          "MCP should be disabled in production environment"
      ensure
        if original_env_var
          ENV["RAILS_ENV"] = original_env_var
        else
          ENV.delete("RAILS_ENV")
        end
      end
    end

    test "authentication works with valid password" do
      Coverband.configuration.mcp_enabled = true
      Coverband.configuration.mcp_password = "test-password"

      handler = Coverband::MCP::HttpHandler.new
      request = create_mock_request_with_auth("Bearer test-password")

      # Should pass authentication
      handler.call(request.env)
      # Note: We're not testing the full response, just that it doesn't error with auth
    end

    test "authentication fails with invalid password" do
      Coverband.configuration.mcp_enabled = true
      Coverband.configuration.mcp_password = "test-password"

      handler = Coverband::MCP::HttpHandler.new
      request = create_mock_request_with_auth("Bearer wrong-password")

      response = handler.call(request.env)

      assert_equal 401, response[0], "Should return 401 Unauthorized"
    end

    test "authentication fails without password" do
      Coverband.configuration.mcp_enabled = true
      Coverband.configuration.mcp_password = "test-password"

      handler = Coverband::MCP::HttpHandler.new
      request = create_mock_request_without_auth

      response = handler.call(request.env)

      assert_equal 401, response[0], "Should return 401 Unauthorized without auth"
    end

    test "allowed environments can be customized" do
      original_envs = Coverband.configuration.mcp_allowed_environments

      begin
        Coverband.configuration.mcp_allowed_environments = ["custom"]
        Coverband.configuration.mcp_enabled = true

        # Should be disabled because "test" is not in custom allowed environments
        refute Coverband.configuration.mcp_enabled?,
          "MCP should respect custom allowed environments"
      ensure
        Coverband.configuration.mcp_allowed_environments = original_envs
      end
    end

    private

    def create_mock_request_with_auth(auth_header)
      request = mock("request")
      request.stubs(:env).returns({
        "REQUEST_METHOD" => "POST",
        "PATH_INFO" => "/mcp",
        "HTTP_AUTHORIZATION" => auth_header,
        "rack.input" => StringIO.new("{}"),
        "CONTENT_TYPE" => "application/json"
      })
      request
    end

    def create_mock_request_without_auth
      request = mock("request")
      request.stubs(:env).returns({
        "REQUEST_METHOD" => "POST",
        "PATH_INFO" => "/mcp",
        "rack.input" => StringIO.new("{}"),
        "CONTENT_TYPE" => "application/json"
      })
      request
    end
  end
end
