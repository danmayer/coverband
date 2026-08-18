# frozen_string_literal: true

module Coverband
  module Storage
    ###
    # Presents a Redis client through the same small interface as an
    # ActiveSupport::Cache store, so the generation pointer and merge protocol
    # are one implementation rather than two.
    #
    # Also exposes the native hash operations, which idempotent presence
    # trackers keep using: per field writes are never reverted by another
    # process, which is stronger than anything a whole document protocol can
    # offer.
    ###
    class RedisTarget
      def initialize(redis)
        @redis = redis
      end

      attr_reader :redis

      def read(key)
        @redis.get(key)
      end

      def read_multi(*keys)
        return {} if keys.empty?

        values = @redis.mget(*keys)
        keys.each_with_object({}).with_index do |(key, found), index|
          found[key] = values[index] unless values[index].nil?
        end
      end

      def write(key, value, options = {})
        if options[:expires_in]
          @redis.set(key, value, ex: options[:expires_in])
        else
          @redis.set(key, value)
        end
        true
      end

      def atomic_create?
        true
      end

      def create(key, value)
        @redis.set(key, value, nx: true)
      end

      def delete(key)
        @redis.del(key)
      end

      def exist?(key)
        if @redis.respond_to?(:exists?)
          @redis.exists?(key)
        else
          @redis.exists(key) > 0
        end
      end

      # native hash operations, used by the idempotent presence trackers
      def hgetall(key)
        @redis.hgetall(key)
      end

      def hset(key, values)
        @redis.hset(key, values)
      end

      def hdel(key, field)
        @redis.hdel(key, field)
      end
    end
  end
end
