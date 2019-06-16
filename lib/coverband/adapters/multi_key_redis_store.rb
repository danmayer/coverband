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
        merged_report = merge_reports(report, coverage(files: report.keys))
        key_values = merged_report.map do |file, data|
          [key(file), data.to_json]
        end.flatten
        @redis.mset(*key_values) if key_values.any?
        keys = merged_report.keys
        @redis.sadd(files_key, keys) if keys.any?
      end

      def coverage(local_type = nil, files: nil)
        files = if files
                  files.map! { |file| full_path_to_relative(file) }
                else
                  files_set(local_type)
                end
        values = if files.any?
                   @redis.mget(*files.map { |file| key(file, local_type) }).map do |value|
                     value.nil? ? {} : JSON.parse(value)
                   end
                 else
                   []
                 end
        Hash[files.zip(values)]
      end

      private

      def files_set(local_type = nil)
        @redis.smembers(files_key(local_type))
      end

      def files_key(local_type = nil)
        "#{key_prefix(local_type)}.files"
      end

      def key(file, local_type = nil)
        [key_prefix(local_type), file].join('.')
      end

      def key_prefix(local_type = nil)
        local_type ||= type
        [@format_version, @redis_namespace, local_type].compact.join('.')
      end
    end
  end
end
