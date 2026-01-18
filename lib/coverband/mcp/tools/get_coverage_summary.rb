# frozen_string_literal: true

module Coverband
  module MCP
    module Tools
      class GetCoverageSummary < ::MCP::Tool
        description "Get overall production code coverage statistics including total files, " \
                    "lines of code, lines covered, and coverage percentage."

        input_schema(
          properties: {}
        )

        def self.call(server_context:, **)
          store = Coverband.configuration.store
          report = Coverband::Reporters::JSONReport.new(store)
          data = JSON.parse(report.report)

          summary = {
            total_files: data["total_files"],
            lines_of_code: data["lines_of_code"],
            lines_covered: data["lines_covered"],
            lines_missed: data["lines_missed"],
            covered_percent: data["covered_percent"],
            covered_strength: data["covered_strength"]
          }

          ::MCP::Tool::Response.new([{
            type: "text",
            text: JSON.pretty_generate(summary)
          }])
        rescue => e
          ::MCP::Tool::Response.new([{
            type: "text",
            text: "Error getting coverage summary: #{e.message}"
          }])
        end
      end
    end
  end
end
