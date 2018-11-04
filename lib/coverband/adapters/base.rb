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
        keys = (new_report.keys + old_report.keys).uniq
        keys.each do |file|
          new_report[file] = if new_report[file] && old_report[file]
                               array_add(new_report[file], old_report[file])
                             elsif new_report[file]
                               new_report[file]
                             else
                               old_report[file]
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
