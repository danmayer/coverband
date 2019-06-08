# frozen_string_literal: true

module Coverband
  module Adapters
    class Base
      include Coverband::Utils::FilePathHelper
      attr_accessor :type

      def initialize
        @file_hash_cache = {}
      end

      def clear!
        raise 'abstract'
      end

      def clear_file!(_file)
        raise 'abstract'
      end

      def migrate!
        raise 'abstract'
      end

      def size
        raise 'abstract'
      end

      def size_in_mib
        format('%.2f', (size.to_f / 2**20))
      end

      def save_report(__report)
        raise 'abstract'
      end

      def coverage(_local_type = nil)
        raise 'abstract'
      end

      def get_coverage_report
        data = Coverband.configuration.store.split_coverage(Coverband::TYPES)
        data.merge(Coverband::MERGED_TYPE => Coverband.configuration.store.merged_coverage(Coverband::TYPES))
      end

      def covered_files
        coverage.keys || []
      end

      protected

      def split_coverage(types)
        types.reduce({}) do |data, type|
          data.update(type => coverage(type))
        end
      end

      def merged_coverage(types)
        types.reduce({}) do |data, type|
          merge_reports(data, coverage(type), skip_expansion: true)
        end
      end

      def save_coverage
        raise 'abstract'
      end

      def file_hash(file)
        @file_hash_cache[file] ||= Digest::MD5.file(file).hexdigest
      end

      def expand_report(report)
        expanded = {}
        report_time = Time.now.to_i
        updated_time = type == Coverband::EAGER_TYPE ? nil : report_time
        report.each_pair do |key, line_data|
          extended_data = {
            'first_updated_at' => report_time,
            'last_updated_at' => updated_time,
            'file_hash' => file_hash(key),
            'data' => line_data
          }
          expanded[full_path_to_relative(key)] = extended_data
        end
        expanded
      end

      def merge_reports(new_report, old_report, options = {})
        new_report = expand_report(new_report) unless options[:skip_expansion]
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
