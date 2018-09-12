# frozen_string_literal: true

###
# TODO current benchmarks aren't showing much advantage from this wrapped cache approach
# re-evaluate before 2.0.0 release 
###
module Coverband
  module Adapters
    class MemoryCacheStore < Base
      attr_accessor :store

      @@files_cache = {}

      def initialize(store)
        @store = store
      end

      def self.clear!
        @@files_cache.clear
      end

      def clear!
        self.class.clear!
      end

      def save_report(files)
        filtered_files = filter(files)
        store.save_report(filtered_files) if filtered_files.any?
      end

      private

      def files_cache
        @@files_cache
      end

      def filter(files)
        files.each_with_object({}) do |(file, covered_lines), filtered_file_hash|
          if covered_lines != cached_file(file)
            files_cache[file] = covered_lines
            filtered_file_hash[file] = covered_lines
          end
        end
      end

      def cached_file(file)
        files_cache[file]  ||= store.covered_lines_for_file(file).each_with_object({}) do |(line_number, value), hash|
          hash[line_number.to_i] = value.to_i
        end
      end
    end
  end
end
