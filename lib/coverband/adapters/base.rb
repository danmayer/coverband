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

      def migrate!
        raise ABSTRACT_KEY
      end

      def size
        raise ABSTRACT_KEY
      end

      def save_coverage
        raise ABSTRACT_KEY
      end

      def coverage(_local_type = nil)
        raise ABSTRACT_KEY
      end

      def size_in_mib
        format("%<size>.2f", size: (size.to_f / 2**20))
      end

      def save_report(_report)
        raise "abstract"
      end

      def get_coverage_report
        data = Coverband.configuration.store.split_coverage(Coverband::TYPES)
        data.merge(Coverband::MERGED_TYPE => Coverband.configuration.store.merged_coverage(Coverband::TYPES))
      end

      def covered_files
        coverage.keys || []
      end

      def raw_store
        raise ABSTRACT_KEY
      end

      protected

      def split_coverage(types)
        types.reduce({}) do |data, type|
          if type == Coverband::RUNTIME_TYPE && Coverband.configuration.simulate_oneshot_lines_coverage
            data.update(type => simulated_runtime_coverage)
          else
            data.update(type => coverage(type))
          end
        end
      end

      def simulated_runtime_coverage
        runtime_data = coverage(Coverband::RUNTIME_TYPE)
        eager_data = coverage(Coverband::EAGER_TYPE)
        eager_data.values do |vals|
          vals["data"].map! { |line_coverage| line_coverage ? (0 - line_coverage) : line_coverage }
        end
        merge_reports(runtime_data, eager_data, skip_expansion: true)
      end

      def merged_coverage(types)
        types.reduce({}) do |data, type|
          merge_reports(data, coverage(type), skip_expansion: true)
        end
      end

      def file_hash(file)
        Coverband::Utils::FileHasher.hash(file)
      end

      # TODO: modify to extend report inline?
      def expand_report(report)
        expanded = {}
        report_time = Time.now.to_i
        updated_time = type == Coverband::EAGER_TYPE ? nil : report_time
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
        # transparent update for format coveband_3_2
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

      # TODO: This should only be 2 cases get our dup / not dups aligned
      def array_add(latest, original)
        if Coverband.configuration.use_oneshot_lines_coverage
          latest.map!.with_index { |v, i| (v + original[i] >= 1 ? 1 : 0) if v && original[i] }
        elsif Coverband.configuration.simulate_oneshot_lines_coverage
          latest.map.with_index { |v, i| (v + original[i] >= 1 ? 1 : 0) if v && original[i] }
        else
          latest.map.with_index { |v, i| v && original[i] ? v + original[i] : nil }
        end
      end
    end
  end
end
