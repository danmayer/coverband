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

      attr_reader :redis_namespace

      def initialize(redis, opts = {})
        super()
        @redis           = redis
        @ttl             = opts[:ttl]
        @redis_namespace = opts[:redis_namespace]
        @format_version  = REDIS_STORAGE_FORMAT_VERSION
        @keys            = {}
        Coverband::TYPES.each do |type|
          @keys[type] = [@format_version, @redis_namespace, type].compact.join('.')
        end
      end

      def clear!
        Coverband::TYPES.each do |type|
          @redis.del(type_base_key(type))
        end
      end

      def clear_file!(filename)
        Coverband::TYPES.each do |type|
          data = coverage(type)
          data.delete(filename)
          save_coverage(data, type)
        end
      end

      def size
        @redis.get(base_key).bytesize
      end

      ###
      # Current implementation moves from coverband3_1 to coverband_3_2
      # In the future this can be made more general and support a more specific
      # version format.
      ###
      def migrate!
        reset_base_key
        @format_version = 'coverband3_1'
        previous_data = coverage
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
        save_coverage(merge_reports(coverage, relative_path_report, skip_expansion: true))
      end

      def type=(type)
        super
        reset_base_key
      end

      def coverage(local_type = nil)
        local_type ||= type
        data = redis.get type_base_key(local_type)
        data ? JSON.parse(data) : {}
      end

      # Note: This could lead to slight race on redis
      # where multiple processes pull the old coverage and add to it then push
      # the Coverband 2 had the same issue,
      # and the tradeoff has always been acceptable
      def save_report(report)
        data = report.dup
        data = merge_reports(data, coverage)
        save_coverage(data)
      end

      private

      attr_reader :redis

      def reset_base_key
        @base_key = nil
      end

      def base_key
        @base_key ||= [@format_version, @redis_namespace, type].compact.join('.')
      end

      def type_base_key(local_type)
        @keys[local_type]
      end

      def save_coverage(data, local_type = nil)
        local_type ||= type
        redis.set type_base_key(local_type), data.to_json
        redis.expire(type_base_key(local_type), @ttl) if @ttl
      end
    end
  end
end
