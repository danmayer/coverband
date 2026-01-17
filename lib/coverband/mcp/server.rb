# frozen_string_literal: true

require_relative "tools/get_coverage_summary"
require_relative "tools/get_file_coverage"
require_relative "tools/get_uncovered_files"
require_relative "tools/get_dead_methods"
require_relative "tools/get_view_tracker_data"
require_relative "tools/get_route_tracker_data"
require_relative "tools/get_translation_tracker_data"

module Coverband
  module MCP
    class Server
      attr_reader :mcp_server

      DEFAULT_HTTP_PORT = 9023

      def initialize
        # Ensure Coverband is configured
        Coverband.configure unless Coverband.configured?

        # Security check: Ensure MCP is enabled and environment is allowed
        unless Coverband.configuration.mcp_enabled?
          raise SecurityError, "MCP is not enabled. Set config.mcp_enabled = true and ensure the current environment is in mcp_allowed_environments."
        end

        @mcp_server = ::MCP::Server.new(
          name: "coverband",
          version: Coverband::VERSION,
          instructions: "Coverband production code coverage MCP server. " \
                        "Query coverage data, find dead code, and analyze view/route/translation usage.",
          tools: tools
        )
      end

      def run_stdio
        transport = ::MCP::Server::Transports::StdioTransport.new(@mcp_server)
        transport.open
      end

      def run_http(port: DEFAULT_HTTP_PORT, host: "localhost")
        require "rack"
        require "rackup"

        transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(@mcp_server)
        @mcp_server.transport = transport

        app = create_rack_app(transport)

        puts <<~MESSAGE
          === Coverband MCP Server (HTTP) ===

          🔒 SECURITY NOTICE:
          This server exposes production coverage data.
          Ensure proper network security (firewall, VPN, etc.)
          Environment: #{(defined?(Rails) && Rails.respond_to?(:env) && Rails.env) || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"}
          Authentication: #{Coverband.configuration.mcp_password ? "✓ Enabled" : "⚠️  DISABLED"}

          Server running at http://#{host}:#{port}

          Available tools:
            - get_coverage_summary
            - get_file_coverage
            - get_uncovered_files
            - get_dead_methods
            - get_view_tracker_data
            - get_route_tracker_data
            - get_translation_tracker_data

          For Claude Desktop, configure with:
            {
              "mcpServers": {
                "coverband": {
                  "command": "npx",
                  "args": ["mcp-remote", "http://#{host}:#{port}"]
                }
              }
            }

          Press Ctrl+C to stop the server
        MESSAGE

        Rackup::Handler.get("puma").run(app, Port: port, Host: host, Silent: true)
      end

      def handle_json(json_request)
        @mcp_server.handle_json(json_request)
      end

      private

      def create_rack_app(transport)
        Rack::Builder.new do
          use Rack::CommonLogger

          run lambda { |env|
            request = Rack::Request.new(env)
            transport.handle_request(request)
          }
        end
      end

      def tools
        [
          Tools::GetCoverageSummary,
          Tools::GetFileCoverage,
          Tools::GetUncoveredFiles,
          Tools::GetDeadMethods,
          Tools::GetViewTrackerData,
          Tools::GetRouteTrackerData,
          Tools::GetTranslationTrackerData
        ]
      end
    end
  end
end
