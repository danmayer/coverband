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

      def clear!
        old_type = type
        Coverband::TYPES.each do |type|
          self.type = type
          file_keys = files_set.map { |file| key(file) }
          @redis.del(*file_keys) if file_keys.any?
          @redis.del(files_key)
        end
        self.type = old_type
      end

      def save_report(report)
        merge_reports(report, coverage(files: report.keys)).each do |file, data|
          @redis.set(key(file), data.to_json)
        end
        @redis.sadd(files_key, report.keys)
      end

      def coverage(files: nil)
        files_to_retrieve = files_set
        files_to_retrieve &= files if files
        files_to_retrieve.each_with_object({}) do |file, coverage|
          coverage[file] = JSON.parse(@redis.get(key(file)))
        end
      end

      private

      def files_set
        @redis.smembers(files_key)
      end

      def files_key
        "#{key_prefix}.files"
      end

      def key(file)
        [key_prefix, file].join('.')
      end

      def key_prefix
        [@format_version, @redis_namespace, type].compact.join('.')
      end
    end
  end
end
