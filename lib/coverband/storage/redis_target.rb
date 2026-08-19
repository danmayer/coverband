# frozen_string_literal: true

module Coverband
  module Storage
    ###
    # A Redis client behind the same small interface as an ActiveSupport::Cache
    # store, so the generation pointer and merge protocol are one implementation
    # rather than two. The native hash operations are exposed too, for the
    # idempotent presence trackers that keep using them.
    ###
    class RedisTarget
      def initialize(redis, ttl: nil)
        @redis = redis
        @ttl = ttl
      end

      attr_reader :redis

      def read(key)
        @redis.get(key)
      end

      # keys are expected frozen: Hash#[]= duplicates and freezes an unfrozen
      # String key, and newer Ruby interns that copy, which reads as a leak here
      def read_multi(*keys)
        return {} if keys.empty?

        values = @redis.mget(*keys)
        keys.each_with_object({}).with_index do |(key, found), index|
          found[key.frozen? ? key : key.dup.freeze] = values[index] unless values[index].nil?
        end
      end

      # a caller supplied expiry wins, otherwise the store's ttl applies;
      # pointers pass expires_in: nil so one can never expire out from under a
      # document that is still being refreshed
      def write(key, value, options = {})
        expiry = options.key?(:expires_in) ? options[:expires_in] : @ttl
        if expiry
          @redis.set(key, value, ex: expiry)
        else
          @redis.set(key, value)
        end
        true
      end

      def atomic_create?
        true
      end

      def create(key, value)
        # deliberately without the store ttl, see #write
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
