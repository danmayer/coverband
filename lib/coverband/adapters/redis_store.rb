# frozen_string_literal: true

module Coverband
  module Adapters
    ###
    # RedisStore store a merged coverage file to redis
    ###
    class RedisStore < Base
      BASE_KEY = 'coverband3'

      def initialize(redis, opts = {})
        @redis           = redis
        @ttl             = opts[:ttl]
        @redis_namespace = opts[:redis_namespace]
      end

      def clear!
        @redis.del(base_key)
      end

      def save_report(report)
        # Note: This could lead to slight races
        # where multiple processes pull the old coverage and add to it then push
        # the Coverband 2 had the same issue,
        # and the tradeoff has always been acceptable
        merge_reports(report, coverage)
        save_coverage(base_key, report)
      end

      def coverage
        get_report(base_key)
      end

      def covered_files
        coverage.keys
      end

      def covered_lines_for_file(file)
        coverage[file]
      end

      private

      attr_reader :redis

      def base_key
        @base_key ||= [BASE_KEY, @redis_namespace].compact.join('.')
      end

      def save_coverage(key, data)
        redis.set key, data.to_json
        redis.expire(key, @ttl) if @ttl
      end

      def get_report(key)
        data = redis.get key
        data ? JSON.parse(data) : {}
      end
    end
  end
end
