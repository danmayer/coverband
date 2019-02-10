# frozen_string_literal: true

require 'digest/sha1'
require 'forwardable'

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
      # Explicitly set the command name that was used for this coverage result.
      # Defaults to Coverband.command_name
      attr_writer :command_name

      def_delegators :files, :covered_percent, :covered_percentages, :least_covered_file, :covered_strength, :covered_lines, :missed_lines
      def_delegator :files, :lines_of_code, :total_lines

      # Initialize a new Coverband::Result from given Coverage.result (a Hash of filenames each containing an array of
      # coverage data)
      def initialize(original_result)
        @original_result = original_result.freeze
        @files = Coverband::Utils::FileList.new(original_result.map do |filename, coverage|
          Coverband::Utils::SourceFile.new(filename, coverage) if File.file?(filename)
        end.compact.sort_by(&:short_name))
        filter!
      end

      # Returns all filenames for source files contained in this result
      def filenames
        files.map(&:filename)
      end

      # Returns a Hash of groups for this result. Define groups using Coverband.add_group 'Models', 'app/models'
      def groups
        @groups ||= FileGroups.new(files).grouped_results
      end

      # Defines when this result has been created. Defaults to Time.now
      def created_at
        @created_at ||= Time.now
      end

      # The command name that launched this result.
      # Delegated to Coverband.command_name if not set manually
      def command_name
        @command_name ||= 'Coverband'
      end

      # Returns a hash representation of this Result that can be used for marshalling it into JSON
      def to_hash
        { command_name => { 'coverage' => coverage, 'timestamp' => created_at.to_i } }
      end

      # Loads a Coverband::Result#to_hash dump
      def self.from_hash(hash)
        command_name, data = hash.first
        result = new(data['coverage'])
        result.command_name = command_name
        result.created_at = Time.at(data['timestamp'])
        result
      end

      # Finds files that were to be tracked but were not loaded and initializes
      # the line-by-line coverage to zero (if relevant) or nil (comments / whitespace etc).
      def self.add_not_loaded_files(result, tracked_files)
        if tracked_files
          result = result.dup
          Dir[tracked_files].each do |file|
            absolute = File.expand_path(file)

            result[absolute] ||= Coverband::Utils::LinesClassifier.new.classify(File.foreach(absolute))
          end
        end

        result
      end

      private

      def coverage
        keys = original_result.keys & filenames
        Hash[keys.zip(original_result.values_at(*keys))]
      end

      # Applies all configured Coverband filters on this result's source files
      def filter!
        @files = files
      end
    end
  end
end
