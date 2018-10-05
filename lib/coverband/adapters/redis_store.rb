# frozen_string_literal: true

module Coverband
  module Adapters
    class RedisStore < Base
      BASE_KEY = 'coverband2'

      attr_accessor :checksum_generator

      class ChecksumGenerator
        def generate(file)
          Digest::MD5.file(file).hexdigest
        end
      end

      def initialize(redis, opts = {})
        @redis = redis
        @ttl             = opts[:ttl]
        @redis_namespace = opts[:redis_namespace]
        @checksum_generator = opts[:checksum_generator] || ChecksumGenerator.new
      end

      def clear!
        @redis.smembers(base_key).each { |key| @redis.del("#{base_key}.#{key}") }
        @redis.del(base_key)
      end

      def base_key
        @base_key ||= [BASE_KEY, @redis_namespace].compact.join('.')
      end

      def save_report(report)
        store_array(base_key, report.keys)

        report.each do |file, lines|
          store_map("#{base_key}.#{file}", @checksum_generator.generate(file), lines)
        end
      end

      def coverage
        data = {}
        redis.smembers(base_key).each do |key|
          data[key] = covered_lines_for_file(key)
        end
        data
      end

      def covered_files
        redis.smembers(base_key)
      end

      def covered_lines_for_file(file)
        @redis.hgetall("#{base_key}.#{file}").reject { |key, _value| key == 'checksum' }
      end

      private

      attr_reader :redis

      def store_map(key, checksum, values)
        unless values.empty?
          existing = redis.hgetall(key)
          # in redis all keys are strings
          values = Hash[values.map { |k, val| [k.to_s, val] }]
          unless checksum != existing['checksum']
            values.merge!(existing) { |_k, old_v, new_v| old_v.to_i + new_v.to_i }
          end
          redis.mapped_hmset(key, values.merge('checksum' => checksum))
          redis.expire(key, @ttl) if @ttl
        end
      end

      def store_array(key, values)
        redis.sadd(key, values) unless values.empty?
        redis.expire(key, @ttl) if @ttl
        values
      end
    end
  end
end
