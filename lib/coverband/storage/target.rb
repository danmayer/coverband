# frozen_string_literal: true

require_relative "io_guard"

module Coverband
  module Storage
    ###
    # The single choke point where Coverband talks to an ActiveSupport::Cache
    # store. Everything goes through here so the storage I/O guard covers reads
    # and deletes, not only writes.
    #
    # The target may be given lazily (a block or callable) because Rails.cache
    # does not exist while config/coverband.rb is loading.
    ###
    class Target
      ATOMIC_CREATE_STORES = [
        "ActiveSupport::Cache::RedisCacheStore",
        "ActiveSupport::Cache::MemCacheStore",
        "SolidCache::Store"
      ].freeze

      def initialize(target = nil, &block)
        @resolver = block || target
        @target = target unless target.respond_to?(:call)
        @mutex = Mutex.new
      end

      ###
      # Resolved once, on first use. The mutex is what makes "exactly once"
      # true when several threads report at the same time on boot.
      ###
      def target
        return @target if @target

        @mutex.synchronize do
          @target ||= @resolver.respond_to?(:call) ? @resolver.call : @resolver
        end
        @target
      end

      def read(key)
        IOGuard.guard { target.read(key) }
      end

      def read_multi(*keys)
        return {} if keys.empty?

        IOGuard.guard do
          if target.respond_to?(:read_multi)
            target.read_multi(*keys)
          else
            keys.each_with_object({}) do |key, found|
              value = target.read(key)
              found[key] = value unless value.nil?
            end
          end
        end
      end

      ###
      # Returns the store's own truthiness. A false write means "not durable"
      # and callers must retain their pending state, so we never coerce it.
      ###
      def write(key, value, options = {})
        IOGuard.guard { target.write(key, value, {expires_in: nil}.merge(options)) }
      end

      ###
      # Whether creation is atomic across the processes that matter, not
      # whether the store accepts the option. MemoryStore and FileStore both
      # accept unless_exist without giving a usable guarantee.
      ###
      def atomic_create?
        ATOMIC_CREATE_STORES.include?(target.class.name)
      end

      def create(key, value)
        return write(key, value) unless atomic_create?

        IOGuard.guard { target.write(key, value, unless_exist: true, expires_in: nil) }
      end

      def delete(key)
        IOGuard.guard { target.delete(key) }
      end

      def exist?(key)
        IOGuard.guard { target.exist?(key) }
      end
    end
  end
end
