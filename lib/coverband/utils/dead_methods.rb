# frozen_string_literal: ntrue

module Coverband
  module Utils
    class DeadMethods
      def self.scan(file_path:, coverage:)
        MethodDefinitionScanner.scan(file_path).reject do |method_definition|
          method_definition.body.coverage?(coverage)
        end
      end
    end
  end
end
