# frozen_string_literal: true

module Coverband
  module Adapters
    class HashRedisStore < Base
      FILE = 'file'
      META_DATA_KEYS = [DATA_KEY, FIRST_UPDATED_KEY, LAST_UPDATED_KEY].freeze
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
        @ttl = opts[:ttl] || -1
      end

      def clear!
        old_type = type
        Coverband::TYPES.each do |type|
          self.type = type
          file_keys = files_set
          @redis.del(*file_keys) if file_keys.any?
          @redis.del(files_key)
        end
        self.type = old_type
      end

      def clear_file!(file)
        relative_path_file = full_path_to_relative(file)
        Coverband::TYPES.each do |type|
          @redis.del(key(relative_path_file, type))
        end
        @redis.srem(files_key, relative_path_file)
      end

      def save_report(report)
        report_time = Time.now.to_i
        updated_time = type == Coverband::EAGER_TYPE ? nil : report_time
        script_id = hash_incr_script
        @redis.pipelined do
          keys = report.map do |file, data|
            relative_file = full_path_to_relative(file)
            key = key(relative_file)
            script_input = save_report_script_input(key: key, file: relative_file, data: data, report_time: report_time, updated_time: updated_time)
            @redis.evalsha(script_id, script_input[:keys], script_input[:args])
            key
          end
          @redis.sadd(files_key, keys) if keys.any?
        end
      end

      def coverage(local_type = nil)
        keys = files_set(local_type)
        keys.each_with_object({}) do |key, hash|
          data_from_redis = @redis.hgetall(key)

          next if data_from_redis.empty?

          max = data_from_redis['file_length'].to_i - 1
          data = Array.new(max + 1) do |index|
            line_coverage = data_from_redis[index.to_s]
            line_coverage.nil? ? nil : line_coverage.to_i
          end
          file = data_from_redis[FILE]
          hash[file] = data_from_redis.select { |meta_data_key, _value| META_DATA_KEYS.include?(meta_data_key) }.merge!('data' => data)
          hash[file][LAST_UPDATED_KEY] = hash[file][LAST_UPDATED_KEY].to_i
          hash[file][FIRST_UPDATED_KEY] = hash[file][FIRST_UPDATED_KEY].to_i
        end
      end

      private

      def save_report_script_input(key:, file:, data:, report_time:, updated_time:)
        data.each_with_index
            .each_with_object(keys: [key], args: [report_time, updated_time, file, file_hash(file), @ttl, data.length]) do |(coverage, index), hash|
          if coverage
            hash[:keys] << index
            hash[:args] << coverage
          end
        end
      end

      def hash_incr_script
        @hash_incr_script ||= @redis.script(:load, <<~LUA)
          local first_updated_at = table.remove(ARGV, 1)
          local last_updated_at = table.remove(ARGV, 1)
          local file = table.remove(ARGV, 1)
          local file_hash = table.remove(ARGV, 1)
          local ttl = table.remove(ARGV, 1)
          local file_length = table.remove(ARGV, 1)
          local hash_key = table.remove(KEYS, 1)
          redis.call('HMSET', hash_key, 'last_updated_at', last_updated_at, 'file', file, 'file_hash', file_hash, 'file_length', file_length)
          redis.call('HSETNX', hash_key, 'first_updated_at', first_updated_at)
          for i, key in ipairs(KEYS) do
            if ARGV[i] == '-1' then
              redis.call("HSET", hash_key, key, ARGV[i])
            else
              redis.call("HINCRBY", hash_key, key, ARGV[i])
            end
          end
          if ttl ~= '-1' then
            redis.call("EXPIRE", hash_key, ttl)
          end
        LUA
      end

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
