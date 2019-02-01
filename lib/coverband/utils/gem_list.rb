# frozen_string_literal: true

####
# An array of  FileLists instances with helpers to roll up the stats
# methods for calculating coverage across them etc.
####
module Coverband
  module Utils
    class GemList < FileList
      # Returns the count of lines that have coverage
      def covered_lines
        to_a.map(&:covered_lines).inject(:+)
      end

      # Returns the count of lines that have been missed
      def missed_lines
        to_a.map(&:missed_lines).inject(:+)
      end

      # Returns the count of lines that are not relevant for coverage
      def never_lines
        to_a.map(&:never_lines).inject(:+)
      end

      # Returns the count of skipped lines
      def skipped_lines
        to_a.map(&:skipped_lines).inject(:+)
      end

      # Computes the coverage based upon lines covered and lines missed for each file
      # Returns an array with all coverage percentages
      def covered_percentages
        map(&:covered_percents)
      end

      # Finds the least covered file and returns that file's name
      def least_covered_file
        sort_by(&:covered_percents).first.filename
      end
    end
  end
end
