# frozen_string_literal: true

module Coverband
  module MCP
    # Rack middleware that adds MCP HTTP endpoint support.
    # Can be used to wrap the existing Coverband::Reporters::Web app
    # or mounted standalone.
    #
    # Usage with existing web UI:
    #   map "/coverage" do
    #     run Coverband::MCP::HttpHandler.new(Coverband::Reporters::Web.new)
    #   end
    #   # MCP endpoint available at POST /coverage/mcp
    #
    # Usage standalone:
    #   map "/mcp" do
    #     run Coverband::MCP::HttpHandler.new
    #   end
    #
    class HttpHandler
      MCP_PATH = "/mcp"

      def initialize(app = nil)
        @app = app
        @server = nil
      end

      def call(env)
        request = Rack::Request.new(env)

        if mcp_request?(request)
          handle_mcp_request(request)
        elsif @app
          @app.call(env)
        else
          not_found_response
        end
      end

      private

      def mcp_request?(request)
        request.post? && request.path_info.end_with?(MCP_PATH)
      end

      def handle_mcp_request(request)
        body = request.body.read
        json_request = JSON.parse(body)
        response = mcp_server.handle_json(json_request)

        [
          200,
          {
            "content-type" => "application/json",
            "access-control-allow-origin" => "*",
            "access-control-allow-methods" => "POST, OPTIONS",
            "access-control-allow-headers" => "Content-Type"
          },
          [response.to_json]
        ]
      rescue JSON::ParserError => e
        error_response(400, "Invalid JSON: #{e.message}")
      rescue => e
        error_response(500, "Server error: #{e.message}")
      end

      def mcp_server
        @server ||= Server.new
      end

      def error_response(status, message)
        [
          status,
          {"content-type" => "application/json"},
          [{error: message}.to_json]
        ]
      end

      def not_found_response
        [404, {"content-type" => "text/plain"}, ["Not Found"]]
      end
    end
  end
end
