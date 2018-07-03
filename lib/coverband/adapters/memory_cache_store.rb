require 'active_support'

module Coverband
  module Adapters
    class MemoryCacheStore
      attr_accessor :store

      def initialize(store, options = {})
        @store       = store
        @max_caching = options[:max_caching] || 1
        @count       = 0
        @filtered_files = {}
      end

      def self.reset!
        files_cache.clear
      end

      def clear!
        self.class.reset!
      end

      def save_report(files)
        @count = @count.succ % @max_caching
        @filtered_files.deep_merge!(filter(files))

        return unless @count.zero?
        return unless @filtered_files.any?
        store.save_report(@filtered_files)
        @filtered_files.clear
      end

      private

      def self.files_cache
        @files_cache ||= Hash.new
      end

      def files_cache
        self.class.files_cache
      end

      def filter(files)
        files.each_with_object(Hash.new) do |(file, lines), filtered_file_hash|
          #first time we see a file, we pre-init the in memory cache to whatever is in store(redis)
          line_cache = files_cache[file] ||= Set.new(store.covered_lines_for_file(file))
          lines.reject! do |line|
            line_cache.include?(line) ? true : (line_cache << line and false)
          end
          filtered_file_hash[file] = lines if lines.any?
        end
      end

    end
  end
end
