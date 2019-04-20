# frozen_string_literal: true
module Coverband
  module Collectors
    class Delta
      @semaphore = Mutex.new
      attr_reader :current_coverage

      def initialize(current_coverage)
        @current_coverage = current_coverage
      end

      def self.results
        @semaphore.synchronize do
          @@previous_coverage ||= {}
          new(::Coverage.peek_result.dup).results
        end
      end

      def results
        new_results = generate
        @@previous_coverage = current_coverage
        new_results
      end

      def self.reset
        @@previous_coverage = nil
      end

      private

      def generate
        current_coverage.each_with_object({}) do |(file, line_counts), new_results|
          if @@previous_coverage[file]
            new_results[file] = array_diff(line_counts, @@previous_coverage[file])
          else
            new_results[file] = line_counts
          end
        end
      end

      def array_diff(latest, original)
        latest.map.with_index do |v, i|
          if (v && original[i])
            [0, v - original[i]].max
          else
            nil
          end
        end
      end
    end
  end
end
