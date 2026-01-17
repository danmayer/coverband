# frozen_string_literal: true

module Coverband
  module MCP
    module Tools
      class GetFileCoverage < ::MCP::Tool
        description "Get detailed line-by-line coverage data for a specific file. " \
                    "Returns coverage percentage, lines covered/missed, and per-line hit counts."

        input_schema(
          properties: {
            filename: {
              type: "string",
              description: "Full or partial path to the file (e.g., 'app/models/user.rb')"
            }
          },
          required: ["filename"]
        )

        def self.call(filename:, server_context:, **)
          store = Coverband.configuration.store
          report = Coverband::Reporters::JSONReport.new(store, {
            filename: filename,
            line_coverage: true
          })

          data = JSON.parse(report.report)

          if data["files"].nil? || data["files"].empty?
            return ::MCP::Tool::Response.new([{
              type: "text",
              text: "No coverage data found for file: #{filename}"
            }])
          end

          # Find matching file(s)
          matching_files = data["files"].select { |path, _| path.include?(filename) }

          if matching_files.empty?
            return ::MCP::Tool::Response.new([{
              type: "text",
              text: "No coverage data found for file matching: #{filename}"
            }])
          end

          result = matching_files.transform_values do |file_data|
            {
              filename: file_data["filename"],
              covered_percent: file_data["covered_percent"],
              lines_of_code: file_data["lines_of_code"],
              lines_covered: file_data["lines_covered"],
              lines_missed: file_data["lines_missed"],
              runtime_percentage: file_data["runtime_percentage"],
              never_loaded: file_data["never_loaded"],
              coverage: file_data["coverage"]
            }
          end

          ::MCP::Tool::Response.new([{
            type: "text",
            text: JSON.pretty_generate(result)
          }])
        rescue => e
          ::MCP::Tool::Response.new([{
            type: "text",
            text: "Error getting file coverage: #{e.message}"
          }])
        end
      end
    end
  end
end
