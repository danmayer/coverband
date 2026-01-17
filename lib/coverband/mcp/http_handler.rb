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
        # Check authentication if MCP password is configured
        unless authenticate_mcp_request(request)
          return [401, {
            "Content-Type" => "application/json",
            "Access-Control-Allow-Origin" => "*",
            "Access-Control-Allow-Methods" => "POST, OPTIONS",
            "Access-Control-Allow-Headers" => "Content-Type, Authorization",
            "WWW-Authenticate" => 'Bearer realm="Coverband MCP"'
          }, [JSON.generate({
            "error" => "Authentication required",
            "message" => "MCP access requires authentication. Provide Bearer token via Authorization header."
          })]]
        end

        body = request.body.read
        json_request = JSON.parse(body)
        response = mcp_server.handle_json(json_request)

        # response might already be a JSON string, so check before converting
        response_body = response.is_a?(String) ? response : response.to_json

        [
          200,
          {
            "content-type" => "application/json",
            "access-control-allow-origin" => "*",
            "access-control-allow-methods" => "POST, OPTIONS",
            "access-control-allow-headers" => "Content-Type"
          },
          [response_body]
        ]
      rescue JSON::ParserError => e
        error_response(400, "Invalid JSON: #{e.message}")
      rescue => e
        error_response(500, "Server error: #{e.message}")
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
