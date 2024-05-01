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

        eager_file = get_eager_file(source_file)
        runtime_file = get_runtime_file(source_file)

        return 0.0 unless runtime_file

        return runtime_file.formatted_covered_percent unless eager_file

        runtime_relavant_lines = eager_file.relevant_lines - eager_file.covered_lines_count
        runtime_file.runtime_relavant_calculations(runtime_relavant_lines) { |file| file.formatted_covered_percent }
      end

      def runtime_relavent_lines(source_file)
        return 0 unless runtime_coverage

        eager_file = get_eager_file(source_file)
        runtime_file = get_runtime_file(source_file)

        return 0 unless runtime_file

        return runtime_file.covered_lines_count unless eager_file

        eager_file.relevant_lines - eager_file.covered_lines_count
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

      def respond_to_missing?(method)
        get_results(type).respond_to?(method)
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
