# frozen_string_literal: true

module Coverband
  module MCP
    module Tools
      class GetRouteTrackerData < ::MCP::Tool
        description "Get Rails route usage tracking data. Shows which routes have been hit " \
                    "in production and which have never been accessed."

        input_schema(
          properties: {
            show_unused_only: {
              type: "boolean",
              description: "Only return unused routes (default: false)"
            }
          }
        )

        def self.call(server_context:, show_unused_only: false, **)
          tracker = Coverband.configuration.route_tracker

          unless tracker
            return ::MCP::Tool::Response.new([{
              type: "text",
              text: "Route tracking is not enabled. Enable it with `config.track_routes = true` in your coverband configuration."
            }])
          end

          data = JSON.parse(tracker.as_json)

          result = if show_unused_only
            {
              tracking_since: tracker.tracking_since,
              unused_routes: data["unused_keys"] || [],
              total_unused: data["unused_keys"]&.length || 0
            }
          else
            {
              tracking_since: tracker.tracking_since,
              used_routes: data["used_keys"] || [],
              unused_routes: data["unused_keys"] || [],
              total_used: data["used_keys"]&.length || 0,
              total_unused: data["unused_keys"]&.length || 0
            }
          end

          ::MCP::Tool::Response.new([{
            type: "text",
            text: JSON.pretty_generate(result)
          }])
        rescue => e
          ::MCP::Tool::Response.new([{
            type: "text",
            text: "Error getting route tracker data: #{e.message}"
          }])
        end
      end
    end
  end
end
