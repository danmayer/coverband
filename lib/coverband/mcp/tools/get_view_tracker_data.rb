# frozen_string_literal: true

module Coverband
  module MCP
    module Tools
      class GetViewTrackerData < ::MCP::Tool
        description "Get Rails view template usage tracking data. Shows which view templates " \
                    "have been rendered in production and which have never been accessed."

        input_schema(
          properties: {
            show_unused_only: {
              type: "boolean",
              description: "Only return unused views (default: false)"
            }
          }
        )

        def self.call(show_unused_only: false, server_context:, **)
          tracker = Coverband.configuration.view_tracker

          unless tracker
            return ::MCP::Tool::Response.new([{
              type: "text",
              text: "View tracking is not enabled. Enable it with `config.track_views = true` in your coverband configuration."
            }])
          end

          data = JSON.parse(tracker.as_json)

          result = if show_unused_only
            {
              tracking_since: tracker.tracking_since,
              unused_views: data["unused_keys"] || [],
              total_unused: data["unused_keys"]&.length || 0
            }
          else
            {
              tracking_since: tracker.tracking_since,
              used_views: data["used_keys"] || [],
              unused_views: data["unused_keys"] || [],
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
            text: "Error getting view tracker data: #{e.message}"
          }])
        end
      end
    end
  end
end
