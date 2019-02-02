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
    end
  end
end
