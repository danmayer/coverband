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

      def initialize
        # Ensure Coverband is configured
        Coverband.configure unless Coverband.configured?

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

      def handle_json(json_request)
        @mcp_server.handle_json(json_request)
      end

      private

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
