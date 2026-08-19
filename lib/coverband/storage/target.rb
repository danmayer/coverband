# frozen_string_literal: true

require_relative "io_guard"

module Coverband
  module Storage
    ###
    # The one place Coverband talks to an ActiveSupport::Cache store, so the
    # storage I/O guard covers reads and deletes, not only writes.
    #
    # The target may be given lazily (a block or callable) because Rails.cache
    # does not exist while config/coverband.rb is loading.
    ###
    class Target
      ###
      # Not a failure: the store exists but is not ready to be resolved yet.
      # Coverband.start runs from before_configuration, so a reporting cycle can
      # land before Rails has assigned Rails.cache. Callers hold their work and
      # try again rather than treating it as a lost write.
      ###
      Unavailable = Class.new(StandardError)

      # the resolver handed back something that is not a cache store, which no
      # later cycle can fix; worth saying once, loudly, rather than every cycle
      # in the same words as the transient case
      Misconfigured = Class.new(Unavailable)

      # the calls the merge protocol makes; a resolver handing back something
      # else is a configuration mistake worth naming
      REQUIRED_METHODS = %i[read write delete].freeze

      ATOMIC_CREATE_STORES = [
        "ActiveSupport::Cache::RedisCacheStore",
        "ActiveSupport::Cache::MemCacheStore",
        "SolidCache::Store"
      ].freeze

      def initialize(target = nil, &block)
        @resolver = block || target
        @mutex = Mutex.new
        @target = usable(target) unless target.respond_to?(:call)
      end

      ###
      # Resolved once, on first use; the mutex is what makes that true when
      # several threads report at the same time on boot. An unusable result is
      # not memoized, so a later cycle can resolve it properly.
      ###
      def target
        return @target if @target

        @mutex.synchronize do
          @target ||= usable(@resolver.respond_to?(:call) ? @resolver.call : @resolver)
        end
        return @target if @target
        raise(@unusable ? Misconfigured : Unavailable, unavailable_message)
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
              # frozen for the same reason as the Redis target's read_multi
              found[key.frozen? ? key : key.dup.freeze] = value unless value.nil?
            end
          end
        end
      end

      # the store's own truthiness: a false write means "not durable" and callers
      # have to retain their pending state, so it is never coerced
      def write(key, value, options = {})
        IOGuard.guard { target.write(key, value, {expires_in: nil}.merge(options)) }
      end

      # whether creation is atomic across processes, not whether the store
      # accepts the option: MemoryStore and FileStore accept unless_exist
      # without giving a usable guarantee
      def atomic_create?
        ATOMIC_CREATE_STORES.include?(target.class.name)
      end

      def create(key, value)
        return write(key, value, expires_in: nil) unless atomic_create?

        IOGuard.guard { target.write(key, value, unless_exist: true, expires_in: nil) }
      end

      def delete(key)
        IOGuard.guard { target.delete(key) }
      end

      def exist?(key)
        IOGuard.guard { target.exist?(key) }
      end

      private

      def usable(resolved)
        return nil if resolved.nil?
        return resolved if REQUIRED_METHODS.all? { |method| resolved.respond_to?(method) }

        @unusable = resolved
        nil
      end

      def unavailable_message
        if @unusable
          "the configured cache store (#{@unusable.class}) does not respond to " \
            "#{REQUIRED_METHODS.join(", ")}, so Coverband cannot store coverage in it"
        else
          "the cache store is not available yet. Rails.cache is assigned after " \
            "Coverband starts, so this resolves on a later reporting cycle"
        end
      end
    end
  end
end
