# frozen_string_literal: true

####
# Thanks for all the help SimpleCov https://github.com/colszowka/simplecov
# initial version pulled into Coverband from Simplecov 12/04/2018
#
# An array of  SourceFile instances with additional collection helper
# methods for calculating coverage across them etc.
####
module Coverband
  module Utils
    class FileList < Array
      # Returns the count of lines that have coverage
      # Using sum avoids intermediate array allocation compared to map.inject
      def covered_lines
        return 0.0 if empty?

        @covered_lines ||= sum(&:covered_lines_count)
      end

      # Returns the count of lines that have been missed
      def missed_lines
        return 0.0 if empty?

        @missed_lines ||= sum(&:missed_lines_count)
      end

      # Returns the count of lines that are not relevant for coverage
      def never_lines
        return 0.0 if empty?

        @never_lines ||= sum(&:never_lines_count)
      end

      # Returns the count of skipped lines
      def skipped_lines
        return 0.0 if empty?

        @skipped_lines ||= sum(&:skipped_lines_count)
      end

      # Computes the coverage based upon lines covered and lines missed for each file
      # Returns an array with all coverage percentages
      def covered_percentages
        map(&:covered_percent)
      end

      # Returns the overall amount of relevant lines of code across all files in this list
      def lines_of_code
        return 0.0 if empty?

        @lines_of_code ||= sum(&:lines_of_code)
      end

      # Computes the coverage based upon lines covered and lines missed
      # @return [Float]
      def covered_percent
        return 100.0 if empty? || lines_of_code.zero?

        Float(covered_lines * 100.0 / lines_of_code)
      end

      # Computes the coverage based upon lines covered and lines missed, formatted
      # @return [Float]
      def formatted_covered_percent
        covered_percent.round(2)
      end

      # Computes the strength (hits / line) based upon lines covered and lines missed
      # @return [Float]
      def covered_strength
        return 0.0 if empty? || lines_of_code.zero?

        Float(sum { |f| f.covered_strength * f.lines_of_code } / lines_of_code)
      end

      def first_seen_at
        min = nil
        each do |f|
          val = f.first_updated_at
          next if val.is_a?(String)
          min = val if min.nil? || val < min
        end
        min
      end
    end
  end
end
