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
    class GemList < FileList
      # Returns the count of lines that have coverage
      def covered_lines
        return 0.0 if empty?
        map { |f| f.covered_lines }.inject(:+)
      end

      # Returns the count of lines that have been missed
      def missed_lines
        return 0.0 if empty?
        map { |f| f.missed_lines }.inject(:+)
      end

      # Returns the count of lines that are not relevant for coverage
      def never_lines
        return 0.0 if empty?
        map { |f| f.never_lines }.inject(:+)
      end

      # Returns the count of skipped lines
      def skipped_lines
        return 0.0 if empty?
        map { |f| f.skipped_lines }.inject(:+)
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
