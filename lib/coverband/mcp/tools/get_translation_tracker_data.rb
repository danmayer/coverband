# frozen_string_literal: true

module Coverband
  module MCP
    module Tools
      class GetTranslationTrackerData < ::MCP::Tool
        description "Get I18n translation key usage tracking data. Shows which translation " \
                    "keys have been used in production and which have never been accessed."

        input_schema(
          properties: {
            show_unused_only: {
              type: "boolean",
              description: "Only return unused translation keys (default: false)"
            }
          }
        )

        def self.call(server_context:, show_unused_only: false, **)
          tracker = Coverband.configuration.translations_tracker

          unless tracker
            return ::MCP::Tool::Response.new([{
              type: "text",
              text: "Translation tracking is not enabled. Enable it with `config.track_translations = true` in your coverband configuration."
            }])
          end

          data = JSON.parse(tracker.as_json)

          result = if show_unused_only
            {
              tracking_since: tracker.tracking_since,
              unused_translations: data["unused_keys"] || [],
              total_unused: data["unused_keys"]&.length || 0
            }
          else
            {
              tracking_since: tracker.tracking_since,
              used_translations: data["used_keys"] || [],
              unused_translations: data["unused_keys"] || [],
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
            text: "Error getting translation tracker data: #{e.message}"
          }])
        end
      end
    end
  end
end
