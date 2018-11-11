# frozen_string_literal: true

module Coverband
  module Adapters
    ###
    # RedisStore store a merged coverage file to redis
    ###
    class RedisStore < Base
      BASE_KEY = 'coverband3_1'

      def initialize(redis, opts = {})
        super()
        @redis           = redis
        @ttl             = opts[:ttl]
        @redis_namespace = opts[:redis_namespace]
      end

      def clear!
        @redis.del(base_key)
      end

      private

      attr_reader :redis

      def base_key
        @base_key ||= [BASE_KEY, @redis_namespace].compact.join('.')
      end

      def save_coverage(data)
        redis.set base_key, data.to_json
        redis.expire(base_key, @ttl) if @ttl
      end

      def get_report
        data = redis.get base_key
        data ? JSON.parse(data) : {}
      end
    end
  end
end
