# frozen_string_literal: true

module Coverband
  module MCP
    module Tools
      class GetUncoveredFiles < ::MCP::Tool
        description "Get files with coverage below a specified threshold. " \
                    "Useful for finding code that may need more production testing or could be dead code."

        input_schema(
          properties: {
            threshold: {
              type: "number",
              description: "Coverage percentage threshold (default: 50). Files below this are returned."
            },
            include_never_loaded: {
              type: "boolean",
              description: "Include files that were never loaded in production (default: true)"
            }
          }
        )

        def self.call(server_context:, threshold: 50, include_never_loaded: true, **)
          store = Coverband.configuration.store
          report = Coverband::Reporters::JSONReport.new(store, line_coverage: false)
          data = JSON.parse(report.report)

          files = data["files"] || {}

          uncovered = files.select do |_path, file_data|
            percent = file_data["covered_percent"] || 0
            never_loaded = file_data["never_loaded"]

            if include_never_loaded
              percent < threshold || never_loaded
            else
              percent < threshold && !never_loaded
            end
          end

          # Sort by coverage percentage ascending (least covered first)
          sorted = uncovered.sort_by { |_path, data| data["covered_percent"] || 0 }

          result = sorted.map do |path, file_data|
            {
              file: path,
              covered_percent: file_data["covered_percent"],
              lines_of_code: file_data["lines_of_code"],
              lines_covered: file_data["lines_covered"],
              lines_missed: file_data["lines_missed"],
              never_loaded: file_data["never_loaded"]
            }
          end

          ::MCP::Tool::Response.new([{
            type: "text",
            text: JSON.pretty_generate({
              threshold: threshold,
              include_never_loaded: include_never_loaded,
              total_uncovered_files: result.length,
              files: result
            })
          }])
        rescue => e
          ::MCP::Tool::Response.new([{
            type: "text",
            text: "Error getting uncovered files: #{e.message}"
          }])
        end
      end
    end
  end
end
