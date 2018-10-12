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

      def save_report(_report)
        raise 'abstract'
      end

      def coverage
        raise 'abstract'
      end

      def covered_files
        raise 'abstract'
      end

      def covered_lines_for_file(_file)
        raise 'abstract'
      end

      protected

      def merge_reports(new_report, old_report)
        new_report.each_pair do |file, line_counts|
          if old_report[file]
            new_report[file] = array_add(line_counts, old_report[file])
          else
            new_report[file] = line_counts
          end
        end
        new_report
      end

      def array_add(latest, original)
        latest.map.with_index { |v, i| (v && original[i]) ? v + original[i] : nil }
      end

    end
  end
end
