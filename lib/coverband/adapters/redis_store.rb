# frozen_string_literal: true

module Coverband
  module Adapters
    class RedisStore < Base
      BASE_KEY = 'coverband3'

      def initialize(redis, opts = {})
        @redis           = redis
        @ttl             = opts[:ttl]
        @redis_namespace = opts[:redis_namespace]
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

        file_keys = report.keys.map {|file| "#{base_key}.#{file}"}
        existing_records = existing_records(file_keys)
        combined_report = combined_report(file_keys, report, existing_records)
        pipelined_save(combined_report)
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
        @redis.hgetall("#{base_key}.#{file}")
      end

      private

      attr_reader :redis
      
      def pipelined_save(combined_report)
        redis.pipelined do
          combined_report.each do |file, values|
            existing = values[:existing]
            new = values[:new]
            unless values.empty?
              # in redis all file_keys are strings
              new_string_values = Hash[new.map {|k, val| [k.to_s, val]}]
              new_string_values.merge!(existing) {|_k, old_v, new_v| old_v.to_i + new_v.to_i}
              redis.mapped_hmset(file, new_string_values)
              redis.expire(file, @ttl) if @ttl
            end
          end
        end
      end

      def existing_records(file_keys)
        redis.pipelined do
          file_keys.each do |key|
            redis.hgetall(key)
          end
        end
      end

      def combined_report(file_keys, report, existing_records)
        combined_report = {}

        file_keys.each_with_index do |key, i|
          combined_report[key] = {
            new: report.values[i],
            existing: existing_records[i]
          }
        end
        
        return combined_report
      end

      def store_array(key, values)
        redis.sadd(key, values) unless values.empty?
        redis.expire(key, @ttl) if @ttl
        values
      end
    end
  end
end
