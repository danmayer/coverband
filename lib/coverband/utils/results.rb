# frozen_string_literal: true

####
# A way to access the various coverage data breakdowns
####
module Coverband
  module Utils
    class Results
      attr_accessor :type, :report

      def initialize(report)
        self.report = report
        self.type = Coverband::MERGED_TYPE
        @results = {}
      end

      def file_with_type(source_file, results_type)
        return unless get_results(results_type)

        @files_with_type ||= {}
        @files_with_type[results_type] ||= get_results(results_type).source_files.map do |source_file|
          [source_file.filename, source_file]
        end.to_h
        @files_with_type[results_type][source_file.filename]
      end

      def runtime_relevant_coverage(source_file)
        return unless eager_loading_coverage && runtime_coverage

        runtime_file = get_runtime_file(source_file)
        return 0.0 unless runtime_file

        line_numbers = runtime_relevant_line_numbers(source_file)
        return 0.0 if line_numbers.empty?

        covered = line_numbers.count { |number| runtime_file.line(number)&.covered? }
        (covered * 100.0 / line_numbers.size).round(2)
      end

      def runtime_relevant_lines(source_file)
        return 0 unless runtime_coverage

        runtime_relevant_line_numbers(source_file).size
      end

      def file_from_path_with_type(full_path, results_type = :merged)
        return unless get_results(results_type)

        @files_from_path_with_type ||= {}
        @files_from_path_with_type[results_type] ||= get_results(results_type).source_files.map do |source_file|
          [source_file.filename, source_file]
        end.to_h
        @files_from_path_with_type[results_type][full_path]
      end

      def method_missing(method, *args)
        if get_results(type).respond_to?(method)
          get_results(type).send(method, *args)
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        get_results(type).respond_to?(method, include_private)
      end

      # Note: small set of hacks for static html simplecov report (groups, created_at, & command_name)
      def groups
        @groups ||= {}
      end

      def created_at
        @created_at ||= Time.now
      end

      def command_name
        @command_name ||= "Coverband"
      end

      private

      ###
      # Runtime relevant lines are the relevant lines that eager loading did not cover.
      # Line relevance comes from real Ruby coverage data, never from a never_loaded
      # placeholder (which marks every line, including blanks and comments, as 0).
      # Lines also hit at runtime by a lazily loading process (class bodies etc.) stay
      # excluded, so runtime coverage can't count them against the smaller denominator.
      ###
      def runtime_relevant_line_numbers(source_file)
        runtime_file = get_runtime_file(source_file)
        return [] unless runtime_file

        eager_file = get_eager_file(source_file)
        eager_file = nil if eager_file&.never_loaded
        reference_file = eager_file || (runtime_file unless runtime_file.never_loaded)
        return [] unless reference_file

        reference_file.lines.filter_map do |line|
          next unless line.covered? || line.missed?
          next if eager_file&.line(line.number)&.covered?

          line.number
        end
      end

      def get_eager_file(source_file)
        file_with_type(source_file, Coverband::EAGER_TYPE)
      end

      def get_runtime_file(source_file)
        file_with_type(source_file, Coverband::RUNTIME_TYPE)
      end

      def eager_loading_coverage
        get_results(Coverband::EAGER_TYPE)
      end

      def runtime_coverage
        get_results(Coverband::RUNTIME_TYPE)
      end

      ###
      # This is a first version of lazy loading the results
      # for the full advantage we need to push lazy loading to the file level
      # inside Coverband::Utils::Result
      ###
      def get_results(type)
        return nil unless Coverband::ALL_TYPES.include?(type)

        @results[type] ||= Coverband::Utils::Result.new(report[type])
      end
    end
  end
end
