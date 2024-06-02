# frozen_string_literal: true

module Coverband
  module Adapters
    class Base
      DATA_KEY = "data"
      FIRST_UPDATED_KEY = "first_updated_at"
      LAST_UPDATED_KEY = "last_updated_at"
      FILE_HASH = "file_hash"
      ABSTRACT_KEY = "abstract"

      attr_accessor :type

      def initialize
        @type = Coverband::RUNTIME_TYPE
      end

      def clear!
        raise ABSTRACT_KEY
      end

      def clear_file!(_file = nil)
        raise ABSTRACT_KEY
      end

      def size
        raise ABSTRACT_KEY
      end

      def save_coverage
        raise ABSTRACT_KEY
      end

      def coverage(_local_type = nil, opts = {})
        raise ABSTRACT_KEY
      end

      def size_in_mib
        if size
          format("%<size>.2f", size: (size.to_f / 2**20))
        else
          "N/A"
        end
      end

      def save_report(_report)
        raise "abstract"
      end

      def get_coverage_report(options = {})
        coverage_cache = {}
        data = Coverband.configuration.store.split_coverage(Coverband::TYPES, coverage_cache, options)
        data.merge(Coverband::MERGED_TYPE => Coverband.configuration.store.merged_coverage(Coverband::TYPES, coverage_cache))
      end

      def covered_files
        coverage.keys || []
      end

      def raw_store
        raise ABSTRACT_KEY
      end

      protected

      def split_coverage(types, coverage_cache, options = {})
        types.reduce({}) do |data, type|
          data.update(type => coverage_cache[type] ||= coverage(type, options))
        end
      end

      def merged_coverage(types, coverage_cache)
        types.reduce({}) do |data, type|
          merge_reports(data, coverage_cache[type] ||= coverage(type), skip_expansion: true)
        end
      end

      def file_hash(file)
        Coverband::Utils::FileHasher.hash_file(file)
      end

      # TODO: modify to extend report inline?
      def expand_report(report)
        expanded = {}
        report_time = Time.now.to_i
        updated_time = (type == Coverband::EAGER_TYPE) ? nil : report_time
        report.each_pair do |key, line_data|
          extended_data = {
            FIRST_UPDATED_KEY => report_time,
            LAST_UPDATED_KEY => updated_time,
            FILE_HASH => file_hash(key),
            DATA_KEY => line_data
          }
          expanded[Utils::RelativeFileConverter.convert(key)] = extended_data
        end
        expanded
      end

      def merge_reports(new_report, old_report, options = {})
        # transparently update from RUNTIME_TYPE = nil to RUNTIME_TYPE = :runtime
        # transparent update for format coverband_3_2
        old_report = coverage(nil, override_type: nil) if old_report.nil? && type == Coverband::RUNTIME_TYPE
        new_report = expand_report(new_report) unless options[:skip_expansion]
        keys = (new_report.keys + old_report.keys).uniq
        keys.each do |file|
          new_report[file] = if new_report[file] &&
              old_report[file] &&
              new_report[file][FILE_HASH] == old_report[file][FILE_HASH]
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
          FIRST_UPDATED_KEY => old_expanded[FIRST_UPDATED_KEY],
          LAST_UPDATED_KEY => new_expanded[LAST_UPDATED_KEY],
          FILE_HASH => new_expanded[FILE_HASH],
          DATA_KEY => array_add(new_expanded[DATA_KEY], old_expanded[DATA_KEY])
        }
      end

      # TODO: This should have cases reduced
      def array_add(latest, original)
        if latest.empty? && original.empty?
          []
        elsif Coverband.configuration.use_oneshot_lines_coverage
          latest.map!.with_index { |v, i| ((v + original[i] >= 1) ? 1 : 0) if v && original[i] }
        else
          latest.map.with_index { |v, i| (v && original[i]) ? v + original[i] : nil }
        end
      end
    end
  end
end
