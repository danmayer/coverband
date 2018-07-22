# frozen_string_literal: true

module Coverband
  module Adapters
    class RedisStore < Base
      BASE_KEY = 'coverband2'

      def initialize(redis, opts = {})
        @redis = redis
      end

      def clear!
        @redis.smembers(BASE_KEY).each { |key| @redis.del("#{BASE_KEY}.#{key}") }
        @redis.del(BASE_KEY)
      end

      def save_report(report)
        store_array(BASE_KEY, report.keys)

        report.each do |file, lines|
          store_map("#{BASE_KEY}.#{file}", lines)
        end
      end

      def coverage
        data = {}
        redis.smembers(BASE_KEY).each do |key|
          data[key] = covered_lines_for_file(key)
        end
        data
      end

      def covered_files
        redis.smembers(BASE_KEY)
      end

      def covered_lines_for_file(file)
        @redis.hgetall("#{BASE_KEY}.#{file}")
      end

      private

      attr_reader :redis

      def store_map(key, values)
        unless values.empty?
          existing = redis.hgetall(key)
          # in redis all keys are strings
          values = Hash[values.map { |k, val| [k.to_s, val] }]
          values.merge!(existing) { |_k, old_v, new_v| old_v.to_i + new_v.to_i }
          redis.mapped_hmset(key, values)
        end
      end

      def store_array(key, values)
        redis.sadd(key, values) unless values.empty?
        values
      end
    end
  end
end
