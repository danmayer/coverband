# frozen_string_literal: true

module Coverband
  module Collectors
    class Delta
      @@previous_coverage = {}
      attr_reader :current_coverage

      def initialize(current_coverage)
        @current_coverage = current_coverage
      end

      class RubyCoverage
        def self.results
          results = ::Coverage.peek_result.dup
          Coverband.configuration.use_oneshot_lines_coverage ? transform_oneshot_lines_results(results) : results
        end

        def self.transform_oneshot_lines_results(results)
          results.each_with_object({}) do |(file, coverage), new_results|
            line_counts = coverage[:oneshot_lines].each_with_object(::Coverage.line_stub(file)) do |line_number, line_counts|
              line_counts[line_number - 1] = 1
            end
            new_results[file] = line_counts
          end
        end
      end

      def self.results(process_coverage = RubyCoverage)
        new(process_coverage.results).results
      end

      def results
        new_results = generate
        @@previous_coverage = current_coverage
        new_results
      end

      def self.reset
        @@previous_coverage = {}
      end

      private

      def generate
        current_coverage.each_with_object({}) do |(file, line_counts), new_results|
          new_results[file] = if @@previous_coverage[file]
                                array_diff(line_counts, @@previous_coverage[file])
                              else
                                line_counts
                              end
        end
      end

      def array_diff(latest, original)
        latest.map.with_index do |v, i|
          [0, v - original[i]].max if v && original[i]
        end
      end
    end
  end
end
