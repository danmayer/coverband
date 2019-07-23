# frozen_string_literal: true

module Coverband
  module Adapters
    class HashRedisStore < Base
      META_DATA_KEYS = [DATA_KEY, FIRST_UPDATED_KEY, LAST_UPDATED_KEY, FILE_HASH].freeze
      ###
      # This key isn't related to the coverband version, but to the interal format
      # used to store data to redis. It is changed only when breaking changes to our
      # redis format are required.
      ###
      REDIS_STORAGE_FORMAT_VERSION = 'coverband_3_3'

      attr_reader :redis_namespace

      def initialize(redis, opts = {})
        super()
        @redis_namespace = opts[:redis_namespace]
        @format_version = REDIS_STORAGE_FORMAT_VERSION
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
        report_time = Time.now.to_i
        updated_time = type == Coverband::EAGER_TYPE ? nil : report_time
        @redis.pipelined do
          report.each do |file, data|
            data.each_with_index do |line_coverage, index|
              key = key(full_path_to_relative(file))
              if line_coverage
                @redis.hincrby(key, index, line_coverage)
              else
                @redis.hset(key, index, -1)
              end
              @redis.hmset(key, LAST_UPDATED_KEY, updated_time, FILE_HASH, file_hash(file))
              @redis.hsetnx(key, FIRST_UPDATED_KEY, report_time)
            end
          end
          keys = report.keys.map { |file| full_path_to_relative(file) }
          @redis.sadd(files_key, keys) if keys.any?
        end
      end

      def coverage(local_type = nil)
        files = files_set(local_type)
        files.each_with_object({}) do |file, hash|
          data_from_redis = @redis.hgetall(key(full_path_to_relative(file), local_type))

          max = (data_from_redis.keys - META_DATA_KEYS).map(&:to_i).max
          data = (max + 1).times.map do |index|
            line_coverage = data_from_redis[index.to_s]
            line_coverage == '-1' ? nil : line_coverage.to_i
          end
          hash[file] = data_from_redis.select { |key, _value| META_DATA_KEYS.include?(key) }.merge!('data' => data)
          hash[file][LAST_UPDATED_KEY] = hash[file][LAST_UPDATED_KEY].to_i
          hash[file][FIRST_UPDATED_KEY] = hash[file][FIRST_UPDATED_KEY].to_i
        end
      end

      private

      def values_from_redis(local_type, files)
        return files if files.empty?

        @redis.mget(*files.map { |file| key(file, local_type) }).map do |value|
          value.nil? ? {} : JSON.parse(value)
        end
      end

      def relative_paths(files)
        files&.map! { |file| full_path_to_relative(file) }
      end

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
