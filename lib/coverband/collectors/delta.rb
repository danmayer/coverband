# frozen_string_literal: true

module Coverband
  module Collectors
    class Delta
      @@previous_coverage = {}
      @@stubs = {}

      attr_reader :current_coverage

      def initialize(current_coverage)
        @current_coverage = current_coverage
      end

      class RubyCoverage
        def self.results
          if Coverband.configuration.use_oneshot_lines_coverage
            ::Coverage.result(clear: true, stop: false)
          else
            ::Coverage.peek_result
          end
        end
      end

      def self.results(process_coverage = RubyCoverage)
        coverage_results = process_coverage.results
        new(coverage_results).results
      end

      def results
        if Coverband.configuration.use_oneshot_lines_coverage
          transform_oneshot_lines_results(current_coverage)
        else
          new_results = generate
          @@previous_coverage = current_coverage
          new_results
        end
      end

      def self.reset
        @@previous_coverage = {}
        @@project_directory = File.expand_path(Coverband.configuration.root)
        @@ignore_patterns = Coverband.configuration.ignore
      end

      private

      def generate
        current_coverage.each_with_object({}) do |(file, line_counts), new_results|
          ###
          # Eager filter:
          # Normally I would break this out into additional methods
          # and improve the readability but this is in a tight loop
          # on the critical performance path, and any refactoring I come up with
          # would slow down the performance.
          ###
          next unless @@ignore_patterns.none? { |pattern| file.match(pattern) } &&
            file.start_with?(@@project_directory)

          # This handles Coverage branch support, setup by default in
          # simplecov 0.18.x
          arr_line_counts = line_counts.is_a?(Hash) ? line_counts[:lines] : line_counts
          new_results[file] = if @@previous_coverage && @@previous_coverage[file]
            prev_line_counts = @@previous_coverage[file].is_a?(Hash) ? @@previous_coverage[file][:lines] : @@previous_coverage[file]
            array_diff(arr_line_counts, prev_line_counts)
          else
            arr_line_counts
          end
        end
      end

      def array_diff(latest, original)
        latest.map.with_index do |v, i|
          [0, v - original[i]].max if v && original[i]
        end
      end

      def transform_oneshot_lines_results(results)
        results.each_with_object({}) do |(file, coverage), new_results|
          ###
          # Eager filter:
          # Normally I would break this out into additional methods
          # and improve the readability but this is in a tight loop
          # on the critical performance path, and any refactoring I come up with
          # would slow down the performance.
          ###
          next unless @@ignore_patterns.none? { |pattern| file.match(pattern) } &&
            file.start_with?(@@project_directory)

          @@stubs[file] ||= ::Coverage.line_stub(file)
          transformed_line_counts = coverage[:oneshot_lines].each_with_object(@@stubs[file].dup) { |line_number, line_counts|
            line_counts[line_number - 1] = 1
          }
          new_results[file] = transformed_line_counts
        end
      end
    end
  end
end
