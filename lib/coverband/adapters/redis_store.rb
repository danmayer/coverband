# frozen_string_literal: true

module Coverband
  module Adapters
    ###
    # RedisStore store a merged coverage file to redis
    ###
    class RedisStore < Base
      ###
      # This key isn't related to the coverband version, but to the interal format
      # used to store data to redis. It is changed only when breaking changes to our
      # redis format are required.
      ###
      REDIS_STORAGE_FORMAT_VERSION = 'coverband_3_2'

      def initialize(redis, opts = {})
        super()
        @redis           = redis
        @ttl             = opts[:ttl]
        @redis_namespace = opts[:redis_namespace]
        @format_version  = REDIS_STORAGE_FORMAT_VERSION
      end

      def clear!
        @redis.del(base_key)
      end

      def size
        @redis.get(REDIS_STORAGE_FORMAT_VERSION).bytesize
      end

      ###
      # Current implementation moves from coverband3_1 to coverband_3_2
      # In the future this can be made more general and support a more specific
      # version format.
      ###
      def migrate!
        reset_base_key
        @format_version = 'coverband3_1'
        previous_data = get_report
        if previous_data.empty?
          puts 'no previous data to migrate found'
          exit 0
        end
        relative_path_report = previous_data.each_with_object({}) do |(key, vals), fixed_report|
          fixed_report[full_path_to_relative(key)] = vals
        end
        clear!
        reset_base_key
        @format_version = REDIS_STORAGE_FORMAT_VERSION
        save_coverage(merge_reports(get_report, relative_path_report, skip_expansion: true))
      end

      private

      attr_reader :redis

      def reset_base_key
        @base_key = nil
      end

      def base_key
        @base_key ||= [@format_version, @redis_namespace].compact.join('.')
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
