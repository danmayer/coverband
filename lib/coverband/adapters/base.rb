# frozen_string_literal: true

module Coverband
  module Adapters
    class Base
      def initialize
        raise 'abstract'
      end

      def clear!
        raise 'abstract'
      end

      def save_report(report)
        raise 'abstract'
      end

      def coverage
        raise 'abstract'
      end

      def covered_files
        raise 'abstract'
      end

      def covered_lines_for_file(file)
        raise 'abstract'
      end
    end
  end
end
