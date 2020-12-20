# frozen_string_literal: ntrue

module Coverband
  module Utils
    class DeadMethods
      def self.scan(file_path:, coverage:)
        MethodDefinitionScanner.scan(file_path).reject do |method_definition|
          method_definition.body.coverage?(coverage)
        end
      end

      def self.scan_all
        coverage = Coverband.configuration.store.coverage
        coverage.flat_map do |file_path, coverage|
          scan(file_path: file_path, coverage: coverage["data"])
        end
      end
    end
  end
end
