# frozen_string_literal: true

module Coverband
  module Adapters
    class MemoryCacheStore < Base
      attr_accessor :store

      def initialize(store)
        @store = store
      end

      def self.reset!
        files_cache.clear
      end

      def clear!
        self.class.reset!
      end

      def save_report(files)
        filtered_files = filter(files)
        store.save_report(filtered_files) if filtered_files.any?
      end

      # rubocop:disable Lint/IneffectiveAccessModifier
      private

      def self.files_cache
        @files_cache ||= {}
      end

      def files_cache
        self.class.files_cache
      end

      def filter(files)
        files.each_with_object({}) do |(file, lines), filtered_file_hash|
          # first time we see a file, we pre-init the in memory cache to whatever is in store(redis)
          line_cache = files_cache[file] ||= Set.new(store.covered_lines_for_file(file))
          lines.reject! do |line|
            line_cache.include?(line) ? true : (line_cache << line && false)
          end
          filtered_file_hash[file] = lines if lines.any?
        end
      end
      # rubocop:enable Lint/IneffectiveAccessModifier
    end
  end
end
