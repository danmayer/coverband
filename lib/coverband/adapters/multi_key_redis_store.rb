# frozen_string_literal: true

module Coverband
  module Adapters
    class MultiKeyRedisStore < Base
      ###
      # This key isn't related to the coverband version, but to the interal format
      # used to store data to redis. It is changed only when breaking changes to our
      # redis format are required.
      ###
      REDIS_STORAGE_FORMAT_VERSION = 'coverband_3_2'

      def initialize(redis, opts = {})
        super()
        @redis_namespace = opts[:redis_namespace]
        @format_version  = REDIS_STORAGE_FORMAT_VERSION
        @redis = redis
      end

      def clear!; end

      def save_report(report)
        merge_reports(report, coverage).each do |file, data|
          @redis.set(key(file), data.to_json)
        end
        @redis.sadd(files_key, report.keys)
      end

      def coverage
        files = @redis.smembers(files_key)
        files.each_with_object({}) do |file, coverage|
          coverage[file] = JSON.parse(@redis.get(key(file)))
        end
      end

      private

      def files_key
        @files_key ||= "#{key_prefix}.files"
      end

      def key(file)
        [key_prefix, file].join('.')
      end

      def key_prefix
        @key_prefix ||= [@format_version, @redis_namespace].compact.join('.')
      end
    end
  end
end
