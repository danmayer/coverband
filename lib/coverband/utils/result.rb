# frozen_string_literal: true

require "digest/sha1"
require "forwardable"

####
# Thanks for all the help SimpleCov https://github.com/colszowka/simplecov
# initial version pulled into Coverband from Simplecov 12/04/2018
#
# A code coverage result, initialized from the Hash stdlib built-in coverage
# library generates (Coverage.result).
####
module Coverband
  module Utils
    class Result
      extend Forwardable
      # Returns the original Coverage.result used for this instance of Coverband::Result
      attr_reader :original_result
      # Returns all files that are applicable to this result (sans filters!)
      # as instances of Coverband::SourceFile. Aliased as :source_files
      attr_reader :files
      alias source_files files
      # Explicitly set the Time this result has been created
      attr_writer :created_at

      def_delegators :files, :covered_percent, :covered_percentages, :covered_strength, :covered_lines, :missed_lines
      def_delegator :files, :lines_of_code, :total_lines

      # Initialize a new Coverband::Result from given Coverage.result (a Hash of filenames each containing an array of
      # coverage data)
      def initialize(original_result)
        @original_result = (original_result || {}).freeze

        @files = Coverband::Utils::FileList.new(@original_result.map { |filename, coverage|
          Coverband::Utils::SourceFile.new(filename, coverage) if File.file?(filename)
        }.compact.sort_by(&:short_name))
      end

      # Returns all filenames for source files contained in this result
      def filenames
        files.map(&:filename)
      end

      # Defines when this result has been created. Defaults to Time.now
      def created_at
        @created_at ||= Time.now
      end

      # Finds files that were to be tracked but were not loaded and initializes
      # the line-by-line coverage to zero (if relevant) or nil (comments / whitespace etc).
      def self.add_not_loaded_files(result, tracked_files)
        if tracked_files
          # TODO: Can we get rid of this dup it wastes memory
          result = result.dup
          Dir[tracked_files].each do |file|
            absolute = File.expand_path(file)
            result[absolute] ||= {
              "data" => [],
              "never_loaded" => true
            }
          end
        end

        result
      end
    end
  end
end
