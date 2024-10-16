# frozen_string_literal: true

####
# Thanks for all the help SimpleCov https://github.com/colszowka/simplecov
# initial version pulled into Coverband from Simplecov 12/04/2018
#
# Representation of a source file including it's coverage data, source code,
# source lines and featuring helpers to interpret that data.
####
module Coverband
  module Utils
    class SourceFile
      # TODO: Refactor Line into its own file
      # Representation of a single line in a source file including
      # this specific line's source code, line_number and code coverage,
      # with the coverage being either nil (coverage not applicable, e.g. comment
      # line), 0 (line not covered) or >1 (the amount of times the line was
      # executed)
      class Line
        # The source code for this line. Aliased as :source
        attr_reader :src
        # The line number in the source file. Aliased as :line, :number
        attr_reader :line_number
        # The coverage data for this line: either nil (never), 0 (missed) or >=1 (times covered)
        attr_reader :coverage
        # Whether this line was skipped
        attr_reader :skipped
        # The coverage data posted time for this line: either nil (never), nil (missed) or Time instance (last posted)
        attr_reader :coverage_posted

        # Lets grab some fancy aliases, shall we?
        alias source src
        alias line line_number
        alias number line_number

        def initialize(src, line_number, coverage, coverage_posted = nil)
          raise ArgumentError, "Only String accepted for source" unless src.is_a?(String)
          raise ArgumentError, "Only Integer accepted for line_number" unless line_number.is_a?(Integer)
          raise ArgumentError, "Only Integer and nil accepted for coverage" unless coverage.is_a?(Integer) || coverage.nil?

          @src = src
          @line_number = line_number
          @coverage = coverage
          @skipped = false
          @coverage_posted = coverage_posted
        end

        # Returns true if this is a line that should have been covered, but was not
        def missed?
          !never? && !skipped? && coverage.zero?
        end

        # Returns true if this is a line that has been covered
        def covered?
          !never? && !skipped? && coverage.positive?
        end

        # Returns true if this line is not relevant for coverage
        def never?
          !skipped? && coverage.nil?
        end

        # Flags this line as skipped
        def skipped!
          @skipped = true
        end

        # Returns true if this line was skipped, false otherwise. Lines are skipped if they are wrapped with
        # # :nocov: comment lines.
        def skipped?
          skipped
        end

        # The status of this line - either covered, missed, skipped or never. Useful i.e. for direct use
        # as a css class in report generation
        def status
          return "skipped" if skipped?
          return "never" if never?
          return "missed" if missed?
          "covered" if covered?
        end
      end

      # The full path to this source file (e.g. /User/colszowka/projects/simplecov/lib/simplecov/source_file.rb)
      attr_reader :filename
      # The array of coverage data received from the Coverage.result
      attr_reader :coverage
      # The array of coverage timedata received from the Coverage.result
      attr_reader :coverage_posted

      # the date this version of the file first started to record coverage
      attr_reader :first_updated_at
      # the date this version of the file last saw any coverage activity
      attr_reader :last_updated_at
      # meta data that the file was never loaded during boot or runtime
      attr_reader :never_loaded
      NOT_AVAILABLE = "not available"

      def initialize(filename, file_data)
        @filename = filename
        @runtime_relavant_lines = nil
        if file_data.is_a?(Hash)
          @coverage = file_data["data"]
          @coverage_posted = file_data["timedata"] || [] # NOTE: only implement timedata for HashRedisStore
          @first_updated_at = @last_updated_at = NOT_AVAILABLE
          @first_updated_at = Time.at(file_data["first_updated_at"]) if file_data["first_updated_at"]
          @last_updated_at = Time.at(file_data["last_updated_at"]) if file_data["last_updated_at"]
          @never_loaded = file_data["never_loaded"] || false
        else
          # TODO: Deprecate this code path this was backwards compatibility from 3-4
          @coverage = file_data
          @first_updated_at = NOT_AVAILABLE
          @last_updated_at = NOT_AVAILABLE
        end
      end

      def runtime_relavant_calculations(runtime_relavant_lines)
        @runtime_relavant_lines = runtime_relavant_lines
        yield self
      ensure
        @runtime_relavant_lines = nil
      end

      # The path to this source file relative to the projects directory
      def project_filename
        @filename.sub(/^#{Coverband.configuration.root}/, "")
      end

      # The source code for this file. Aliased as :source
      def src
        # We intentionally read source code lazily to
        # suppress reading unused source code.
        @src ||= File.open(filename, "rb", &:readlines)
      end
      alias source src

      # Returns all source lines for this file as instances of SimpleCov::SourceFile::Line,
      # and thus including coverage data. Aliased as :source_lines
      def lines
        @lines ||= build_lines
      end
      alias source_lines lines

      def build_lines
        coverage_exceeding_source_warn if coverage.size > src.size

        lines = src.map.with_index(1) { |src, i|
          Coverband::Utils::SourceFile::Line.new(
            src,
            i,
            never_loaded ? 0 : coverage[i - 1],
            (never_loaded || !coverage_posted.is_a?(Array)) ? nil : coverage_posted[i - 1]
          )
        }

        process_skipped_lines(lines)
      end

      # Warning to identify condition from Issue #56
      def coverage_exceeding_source_warn
        warn "Warning: coverage data from Coverage [#{coverage.size}] exceeds line count in #{filename} [#{src.size}]"
      end

      # Access SimpleCov::SourceFile::Line source lines by line number
      def line(number)
        lines[number - 1]
      end

      # The coverage for this file in percent. 0 if the file has no relevant lines
      def covered_percent
        return 100.0 if no_lines?

        return 0.0 if relevant_lines.zero?

        # handle edge case where runtime in dev can go over 100%
        [Float(covered_lines.size * 100.0 / relevant_lines.to_f), 100.0].min&.round(2)
      end

      def formatted_covered_percent
        covered_percent&.round(2)
      end

      def covered_strength
        return 0.0 if relevant_lines.zero?

        round_float(lines_strength / relevant_lines.to_f, 1)
      end

      def no_lines?
        lines.length.zero? || (lines.length == never_lines.size)
      end

      def lines_strength
        lines.sum do |line|
          line.coverage || 0
        end
      end

      def relevant_lines
        @runtime_relavant_lines || (lines.size - never_lines.size - skipped_lines.size)
      end

      # Returns all covered lines as SimpleCov::SourceFile::Line
      def covered_lines
        @covered_lines ||= lines.select(&:covered?)
      end

      def covered_lines_count
        covered_lines&.count
      end

      def line_coverage(index)
        lines[index]&.coverage
      end

      def line_coverage_posted(index)
        lines[index]&.coverage_posted
      end

      # Returns all lines that should have been, but were not covered
      # as instances of SimpleCov::SourceFile::Line
      def missed_lines
        @missed_lines ||= lines.select(&:missed?)
      end

      # Returns all lines that are not relevant for coverage as
      # SimpleCov::SourceFile::Line instances
      def never_lines
        @never_lines ||= lines.select(&:never?)
      end

      # Returns all lines that were skipped as SimpleCov::SourceFile::Line instances
      def skipped_lines
        @skipped_lines ||= lines.select(&:skipped?)
      end

      # Returns the number of relevant lines (covered + missed)
      def lines_of_code
        covered_lines.size + missed_lines.size
      end

      # Will go through all source files and mark lines that are wrapped within # :nocov: comment blocks
      # as skipped.
      def process_skipped_lines(lines)
        skipping = false

        lines.each do |line|
          if Coverband::Utils::LinesClassifier.no_cov_line?(line.src)
            skipping = !skipping
            line.skipped!
          elsif skipping
            line.skipped!
          end
        end
      end

      # a bug that existed in simplecov was not checking that root
      # was at the start of the file name
      # I had previously patched this in my local Rails app
      def short_name
        filename.delete_prefix("#{Coverband.configuration.root}/")
      end

      def relative_path
        RelativeFileConverter.convert(filename)
      end

      private

      # ruby 1.9 could use Float#round(places) instead
      # @return [Float]
      def round_float(float, places)
        factor = Float(10 * places)
        Float((float * factor).round / factor)
      end
    end
  end
end
