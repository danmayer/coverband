# frozen_string_literal: true

module Coverband
  module Adapters
    class RedisStore
      BASE_KEY = 'coverband1'

      def initialize(redis, opts = {})
        @redis = redis
        # remove check for coverband 2.0
        @_sadd_supports_array = recent_gem_version? && recent_server_version?
        # possibly drop array storage for 2.0
        @store_as_array = opts.fetch(:array) { false }
      end

      def clear!
        @redis.smembers(BASE_KEY).each { |key| @redis.del("#{BASE_KEY}.#{key}") }
        @redis.del(BASE_KEY)
      end

      def save_report(report)
        if @store_as_array
          redis.pipelined do
            store_array(BASE_KEY, report.keys)

            report.each do |file, lines|
              store_array("#{BASE_KEY}.#{file}", lines.keys)
            end
          end
        else
          store_array(BASE_KEY, report.keys)

          report.each do |file, lines|
            store_map("#{BASE_KEY}.#{file}", lines)
          end
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
        if @store_as_array
          @redis.smembers("#{BASE_KEY}.#{file}").map(&:to_i)
        else
          @redis.hgetall("#{BASE_KEY}.#{file}")
        end
      end

      private

      attr_reader :redis

      def sadd_supports_array?
        @_sadd_supports_array
      end

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
        if sadd_supports_array?
          redis.sadd(key, values) unless values.empty?
        else
          values.each do |value|
            redis.sadd(key, value)
          end
        end
        values
      end

      def recent_server_version?
        info_data = redis.info
        if info_data.is_a?(Hash)
          Gem::Version.new(info_data['redis_version']) >= Gem::Version.new('2.4')
        else
          # guess supported
          true
        end
      end

      def recent_gem_version?
        Gem::Version.new(Redis::VERSION) >= Gem::Version.new('3.0')
      end
    end
  end
end
