# frozen_string_literal: true

module Coverband
  module MCP
    module Tools
      class GetStorageHealth < ::MCP::Tool
        description "Get Coverband's observed coverage and tracker storage protocol state, " \
                    "including stalled writes and recorded data loss. This is not an active backend probe."

        input_schema(
          properties: {}
        )

        def self.call(server_context:, **)
          ::MCP::Tool::Response.new([{
            type: "text",
            text: JSON.pretty_generate(Coverband.storage_health)
          }])
        rescue => e
          ::MCP::Tool::Response.new([{
            type: "text",
            text: "Error getting storage health: #{e.message}"
          }])
        end
      end
    end
  end
end
