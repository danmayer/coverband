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

        get_results(results_type).source_files.find { |file| file.filename == source_file.filename }
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
        return 0 unless eager_loading_coverage && runtime_coverage

        eager_file = get_eager_file(source_file)
        runtime_file = get_runtime_file(source_file)

        return runtime_file.covered_lines_count unless eager_file

        eager_file.relevant_lines - eager_file.covered_lines_count
      end

      ###
      # TODO: Groups still have some issues, this should be generic for groups, but right now gem_name
      # is specifically called out, need to revisit all gorups code.
      ###
      def group_file_list_with_type(group, file_list, results_type)
        return unless get_results(results_type)

        get_results(results_type).groups[group].find { |gem_files| gem_files.first.gem_name == file_list.first.gem_name }
      end

      def file_from_path_with_type(full_path, results_type = :merged)
        return unless get_results(results_type)

        get_results(results_type).source_files.find { |file| file.filename == full_path }
      end

      def method_missing(method, *args)
        if get_results(type).respond_to?(method)
          get_results(type).send(method, *args)
        else
          super
        end
      end

      def respond_to_missing?(method)
        if get_results(type).respond_to?(method)
          true
        else
          false
        end
      end

      private

      def get_eager_file(source_file)
        eager_loading_coverage.source_files.find { |file| file.filename == source_file.filename }
      end

      def get_runtime_file(source_file)
        runtime_coverage.source_files.find { |file| file.filename == source_file.filename }
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

        if @results.key?(type)
          @results[type]
        else
          @results[type] = Coverband::Utils::Result.new(report[type])
        end
      end
    end
  end
end
