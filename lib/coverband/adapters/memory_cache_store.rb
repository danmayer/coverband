require 'active_support'

module Coverband
  module Adapters
    class MemoryCacheStore
      attr_accessor :store

      def initialize(store, options = {})
        @store       = store
        @max_caching = options[:max_caching] || 1
        @count       = 0
        @cached_data = {}
      end

      def save_report(files)
        @count = @count.succ % @max_caching
        files.each_with_object(@cached_data) do |(file, lines), cached_data|
          line_cache = cached_data[file] ||= {}
          line_cache.merge!(lines) { |k, old_v, new_v| old_v.to_i + new_v.to_i }
          cached_data[file] = line_cache
        end

        return unless @count.zero?
        return unless @cached_data.any?
        store.save_report(@cached_data)
        @cached_data.clear
      end

    end
  end
end
