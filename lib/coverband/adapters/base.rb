# frozen_string_literal: true

module Coverband
  module Adapters
    class Base
      include Coverband::Utils::FilePathHelper

      def initialize
        @file_hash_cache = {}
      end

      def clear!
        raise 'abstract'
      end

      # Note: This could lead to slight race on redis
      # where multiple processes pull the old coverage and add to it then push
      # the Coverband 2 had the same issue,
      # and the tradeoff has always been acceptable
      def save_report(report)
        data = report.dup
        data = merge_reports(data, get_report)
        save_coverage(data)
      end

      def coverage
        get_report
      end

      def covered_files
        coverage.keys || []
      end

      # TODO: deprecate / remove?
      def covered_lines_for_file(file)
        Array(coverage.dig(file, 'data'))
      end

      protected

      def save_coverage
        raise 'abstract'
      end

      def get_report
        raise 'abstract'
      end

      def file_hash(file)
        @file_hash_cache[file] ||= Digest::MD5.file(file).hexdigest
      end

      def expand_report(report)
        expanded = {}
        report_time = Time.now.to_i
        report.each_pair do |key, line_data|
          extended_data = {
            'first_updated_at' => report_time,
            'last_updated_at' => report_time,
            'file_hash' => file_hash(key),
            'data' => line_data
          }
          expanded[full_path_to_relative(key)] = extended_data
        end
        expanded
      end

      def merge_reports(new_report, old_report)
        new_report = expand_report(new_report)
        keys = (new_report.keys + old_report.keys).uniq
        keys.each do |file|
          new_report[file] = if new_report[file] &&
                                old_report[file] &&
                                new_report[file]['file_hash'] == old_report[file]['file_hash']
                               merge_expanded_data(new_report[file], old_report[file])
                             elsif new_report[file]
                               new_report[file]
                             else
                               old_report[file]
                             end
        end
        new_report
      end

      def merge_expanded_data(new_expanded, old_expanded)
        {
          'first_updated_at' => old_expanded['first_updated_at'],
          'last_updated_at' => new_expanded['last_updated_at'],
          'file_hash' => new_expanded['file_hash'],
          'data' => array_add(new_expanded['data'], old_expanded['data'])
        }
      end

      def array_add(latest, original)
        latest.map.with_index { |v, i| (v && original[i]) ? v + original[i] : nil }
      end
    end
  end
end
