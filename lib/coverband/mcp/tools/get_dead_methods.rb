# frozen_string_literal: true

module Coverband
  module MCP
    module Tools
      class GetDeadMethods < ::MCP::Tool
        title "Get Dead Methods"
        description "Analyze code coverage to find methods that have never been executed in production. " \
                    "Requires Ruby 2.6+ with RubyVM::AbstractSyntaxTree support."

        input_schema(
          type: "object",
          properties: {
            file_pattern: {
              type: "string",
              description: "Optional glob pattern to filter files (e.g., 'app/models/**/*.rb')"
            }
          },
          required: []
        )

        def self.call(file_pattern: nil, server_context:, **)
          unless defined?(RubyVM::AbstractSyntaxTree)
            return ::MCP::Tool::Response.new([{
              type: "text",
              text: "Dead method detection requires Ruby 2.6+ with RubyVM::AbstractSyntaxTree support."
            }], is_error: true)
          end

          dead_methods = Coverband::Utils::DeadMethods.scan_all

          if file_pattern
            dead_methods = dead_methods.select do |method|
              File.fnmatch(file_pattern, method[:file_path], File::FNM_PATHNAME)
            end
          end

          # Group by file for easier reading
          grouped = dead_methods.group_by { |m| m[:file_path] }

          result = grouped.map do |file_path, methods|
            {
              file: file_path,
              dead_methods: methods.map do |m|
                {
                  class_name: m[:class_name],
                  method_name: m[:method_name],
                  line_number: m[:line_number]
                }
              end
            }
          end

          ::MCP::Tool::Response.new([{
            type: "text",
            text: JSON.pretty_generate({
              total_dead_methods: dead_methods.length,
              files_with_dead_methods: grouped.keys.length,
              file_pattern: file_pattern,
              results: result
            })
          }])
        rescue => e
          ::MCP::Tool::Response.new([{
            type: "text",
            text: "Error analyzing dead methods: #{e.message}"
          }], is_error: true)
        end
      end
    end
  end
end
