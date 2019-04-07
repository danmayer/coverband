# frozen_string_literal: true

####
# A way to access the various coverage data breakdowns
####
module Coverband
  module Utils
    class CoverbandResults
      attr_accessor :type, :results

      def initialize(report)
        self.results = {
          Coverband::EAGER_TYPE => Coverband::Utils::Result.new(report[Coverband::EAGER_TYPE]),
          Coverband::RUNTIME_TYPE => Coverband::Utils::Result.new(report[Coverband::RUNTIME_TYPE]),
          Coverband::MERGED_TYPE => Coverband::Utils::Result.new(report[Coverband::MERGED_TYPE])
        }
        self.type = Coverband::MERGED_TYPE
      end

      def file_with_type(source_file, results_type)
        results[results_type].source_files.find { |file| file.filename == source_file.filename }
      end

      def from_type(results_type)
        original_type = type
        self.type = results_type
        yield
      ensure
        self.type = original_type
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
