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
