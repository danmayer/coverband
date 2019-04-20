# frozen_string_literal: true

####
# A way to access the various coverage data breakdowns
####
module Coverband
  module Utils
    class Results
      attr_accessor :type, :results

      def initialize(report)
        self.results = (Coverband::TYPES + [:merged]).each_with_object({}) do |type, hash|
          hash[type] = Coverband::Utils::Result.new(report[type])
        end
        self.type = Coverband::MERGED_TYPE
      end

      def file_with_type(source_file, results_type)
        return unless results[results_type]

        results[results_type].source_files.find { |file| file.filename == source_file.filename }
      end

      def file_from_path_with_type(full_path, results_type = :merged)
        return unless results[results_type]
        
        results[results_type].source_files.find { |file| file.filename == full_path }
      end

      def method_missing(method, *args)
        if results[type].respond_to?(method)
          results[type].send(method, *args)
        else
          super
        end
      end

      def respond_to_missing?(method)
        if results[type].respond_to?(method)
          true
        else
          false
        end
      end
    end
  end
end
