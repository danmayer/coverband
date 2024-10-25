# frozen_string_literal: true

require "coverband/utils/method_definition_scanner"

module Coverband
  module Utils
    module ArrayToTableInConsole
      refine Array do
        def to_table
          column_sizes =
            reduce([]) { |lengths, row|
              row.each_with_index.map do |iterand, index|
                [lengths[index] || 0, iterand.to_s.length].max
              end
            }
          puts head =
                 "-" * (column_sizes.inject(&:+) + (3 * column_sizes.count) + 1)
          each do |row|
            row = row.fill(nil, row.size..(column_sizes.size - 1))
            row =
              row.each_with_index.map { |v, i|
                v.to_s + " " * (column_sizes[i] - v.to_s.length)
              }
            puts "| " + row.join(" | ") + " |"
          end
          puts head
        end
      end
    end

    class DeadMethods
      using ArrayToTableInConsole
      def self.scan(file_path:, coverage:)
        MethodDefinitionScanner.scan(file_path).reject do |method_definition|
          method_definition.body.coverage?(coverage)
        end
      end

      def self.scan_all
        # If the file was loaded during eager loading and then its code is never executed
        # during runtime, then it will not have any runtime coverage. When reporting
        # dead methods, we need to look at all the files discovered during the eager loading
        # and runtime phases.
        coverage = Coverband.configuration.store.get_coverage_report[Coverband::MERGED_TYPE]
        coverage.flat_map do |file_path, coverage|
          scan(file_path: file_path, coverage: coverage["data"])
        end
      end

      def self.output_all
        rows =
          scan_all.each_with_object(
            [%w[file class method line_number]]
          ) { |dead_method, rows|
            rows <<
              [
                dead_method.file_path,
                dead_method.class_name,
                dead_method.name,
                dead_method.first_line_number
              ]
          }
        rows.to_table
      end
    end
  end
end
