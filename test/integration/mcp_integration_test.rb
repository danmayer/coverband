# frozen_string_literal: true

require File.expand_path("../test_helper", File.dirname(__FILE__))

begin
  require "coverband/mcp"
rescue LoadError
  puts "MCP gem not available, skipping MCP integration tests"
end

if defined?(Coverband::MCP)
  class MCPIntegrationTest < Minitest::Test
    def setup
      super
      Coverband.configure do |config|
        config.store = Coverband::Adapters::RedisStore.new(Redis.new(db: 2))
        config.mcp_enabled = true  # Enable MCP for testing
      end

      # Populate some test coverage data
      store = Coverband.configuration.store
      coverage_data = {
        "/app/models/user.rb" => [1, 1, 0, 1, nil, 1, 0],
        "/app/models/order.rb" => [1, 1, 1, 1, 1]
      }
      store.save_report(coverage_data)

      @server = Coverband::MCP::Server.new
    end

    def teardown
      super
      Coverband.configuration.store&.clear!
    end

    test "MCP integration with dependency checking" do
      # Test that all components load correctly together
      refute_nil @server
      refute_nil @server.mcp_server
      refute_empty @server.mcp_server.tools
    end

    test "end-to-end MCP request handling via server" do
      # Simulate an MCP request for coverage summary
      json_request = {
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "params" => {
          "name" => "Get Coverage Summary",
          "arguments" => {}
        },
        "id" => 1
      }

      # This should work without throwing exceptions
      response = @server.handle_json(json_request.to_json)

      # Basic validation that we got a response
      refute_nil response
    end

    test "MCP tools integrate correctly with Coverband configuration" do
      # Test that tools can access Coverband store and configuration
      assert_respond_to Coverband.configuration, :store
      assert_respond_to Coverband.configuration.store, :coverage

      # Verify each tool class is properly defined
      [
        Coverband::MCP::Tools::GetCoverageSummary,
        Coverband::MCP::Tools::GetFileCoverage,
        Coverband::MCP::Tools::GetUncoveredFiles,
        Coverband::MCP::Tools::GetDeadMethods,
        Coverband::MCP::Tools::GetViewTrackerData,
        Coverband::MCP::Tools::GetRouteTrackerData,
        Coverband::MCP::Tools::GetTranslationTrackerData
      ].each do |tool_class|
        assert_respond_to tool_class, :call
        assert_respond_to tool_class, :title
        assert_respond_to tool_class, :description
        assert_respond_to tool_class, :input_schema
      end
    end

    test "HTTP handler integrates with MCP server" do
      handler = Coverband::MCP::HttpHandler.new

      # Verify handler can create and use MCP server
      server = handler.send(:mcp_server)
      assert_instance_of Coverband::MCP::Server, server

      # Verify handler responds to rack interface
      assert_respond_to handler, :call
    end

    test "bin/coverband-mcp executable dependencies" do
      # Test that the executable can be loaded
      executable_path = File.expand_path("../../bin/coverband-mcp", File.dirname(__FILE__))
      assert File.exist?(executable_path), "Executable should exist"
      assert File.executable?(executable_path), "File should be executable"

      # Read the content to verify it requires the right modules
      content = File.read(executable_path)
      assert_includes content, 'require "coverband/mcp"'
      assert_includes content, "Coverband::MCP::Server.new"
    end

    test "MCP module properly handles missing dependencies" do
      # Temporarily hide the MCP module to test error handling
      if defined?(::MCP)
        original_mcp = ::MCP
        Object.send(:remove_const, :MCP)
      end

      begin
        # This should raise a LoadError with helpful message when requiring
        error = assert_raises(NameError) do
          # Force re-evaluation of the conditional
          eval("Coverband::MCP::Server.new", binding, __FILE__, __LINE__)
        end

        assert_includes error.message, "MCP"
      ensure
        # Restore the constant
        if defined?(original_mcp)
          Object.const_set(:MCP, original_mcp)
        end
      end
    end

    test "all tools return properly formatted MCP responses" do
      # Test that each tool returns a valid MCP::Tool::Response
      tools = [
        [Coverband::MCP::Tools::GetCoverageSummary, {}],
        [Coverband::MCP::Tools::GetFileCoverage, {filename: "user.rb"}],
        [Coverband::MCP::Tools::GetUncoveredFiles, {threshold: 50}],
        [Coverband::MCP::Tools::GetDeadMethods, {}],
        [Coverband::MCP::Tools::GetViewTrackerData, {}],
        [Coverband::MCP::Tools::GetRouteTrackerData, {}],
        [Coverband::MCP::Tools::GetTranslationTrackerData, {}]
      ]

      tools.each do |tool_class, params|
        response = tool_class.call(**params, server_context: {})

        assert_instance_of ::MCP::Tool::Response, response,
          "#{tool_class} should return MCP::Tool::Response"
        assert_respond_to response, :content
        assert response.content.is_a?(Array), "Content should be an array"

        # Check content structure
        assert response.content.length > 0, "Responses should have content"
        assert_equal "text", response.content.first[:type],
          "Content should have text type"
      rescue => e
        # Some tools may fail due to missing features/config, but should handle gracefully
        flunk "#{tool_class} raised unhandled exception: #{e.class}: #{e.message}"
      end
    end

    test "MCP server transport configurations" do
      # Test that server can be configured for different transports
      server = Coverband::MCP::Server.new

      # STDIO transport
      transport_mock = mock("stdio_transport")
      transport_mock.expects(:open).once
      ::MCP::Server::Transports::StdioTransport.expects(:new).returns(transport_mock)

      server.run_stdio

      # HTTP transport setup (without actually starting server)
      assert_equal 9023, Coverband::MCP::Server::DEFAULT_HTTP_PORT
    end
  end
end
