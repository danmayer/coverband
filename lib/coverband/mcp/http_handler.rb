# frozen_string_literal: true

module Coverband
  module MCP
    # Rack middleware that adds MCP HTTP endpoint support using StreamableHTTPTransport.
    # Can be used to wrap the existing Coverband::Reporters::Web app
    # or mounted standalone.
    #
    # Usage with existing web UI:
    #   map "/coverage" do
    #     run Coverband::MCP::HttpHandler.new(Coverband::Reporters::Web.new)
    #   end
    #   # MCP endpoint available at /coverage/mcp with full Streamable HTTP transport support
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
        @transport = nil
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
        # Accept GET, POST, DELETE, OPTIONS for StreamableHTTPTransport protocol
        %w[GET POST DELETE OPTIONS].include?(request.request_method) &&
          request.path_info.end_with?(MCP_PATH)
      end

      def handle_mcp_request(request)
        # Handle CORS preflight
        return cors_preflight_response if request.request_method == "OPTIONS"

        # Check authentication if MCP password is configured
        unless authenticate_mcp_request(request)
          return [401, {
            "Content-Type" => "application/json",
            "Access-Control-Allow-Origin" => "*",
            "Access-Control-Allow-Methods" => "GET, POST, DELETE, OPTIONS",
            "Access-Control-Allow-Headers" => "Content-Type, Authorization, Accept, Mcp-Session-Id",
            "WWW-Authenticate" => 'Bearer realm="Coverband MCP"'
          }, [JSON.generate({
            "error" => "Authentication required",
            "message" => "MCP access requires authentication. Provide Bearer token via Authorization header."
          })]]
        end

        # Delegate to StreamableHTTPTransport which handles the full MCP HTTP protocol
        # (GET for SSE streams, POST for requests/responses, DELETE for cleanup, etc.)
        transport.handle_request(request)
      rescue => e
        error_response(500, "Server error: #{e.message}")
      end

      def cors_preflight_response
        [204, {
          "Access-Control-Allow-Origin" => "*",
          "Access-Control-Allow-Methods" => "GET, POST, DELETE, OPTIONS",
          "Access-Control-Allow-Headers" => "Content-Type, Authorization, Accept, Mcp-Session-Id"
        }, []]
      end

      def authenticate_mcp_request(request)
        # If no MCP password is configured, allow access
        mcp_password = Coverband.configuration.mcp_password
        return true unless mcp_password

        # Extract Bearer token from Authorization header
        auth_header = request.get_header("HTTP_AUTHORIZATION")
        return false unless auth_header

        # Parse Bearer token
        token = auth_header[/Bearer (.+)/, 1]
        return false unless token

        # Compare with configured MCP password
        token == mcp_password
      end

      def transport
        @transport ||= begin
          server = ::Coverband::MCP::Server.new
          ::MCP::Server::Transports::StreamableHTTPTransport.new(server.mcp_server)
        end
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
