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
        #@redis.smembers(base_key).each { |key| @redis.del("#{base_key}.#{key}") }
        @redis.del(base_key)
      end

      def base_key
        @base_key ||= [BASE_KEY, @redis_namespace].compact.join('.')
      end

      def save_report(report)
        merge_reports(report, coverage)
        save_coverage(base_key, report)
      end

      def coverage
        get_report(base_key)
      end

      def covered_files
        coverage.keys
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

      def merge_reports(new_report, old_report)
        new_report.each_pair do |file, line_counts|
          if old_report[file]
            new_report[file] = array_add(line_counts, old_report[file])
          else
            new_report[file] = line_counts
          end
        end
        new_report
      end

      def array_add(latest, original)
        latest.map.with_index { |v, i| (v && original[i]) ? v + original[i] : nil }
      end

      def hash_add(latest, original)
        merged_values = {}
        latest.each_pair do |k, v|
          new_v = (v && original[k.to_s]) ? v + original[k.to_s] : v
          merged_values[k] = new_v
        end
        merged_values
      end

      def save_coverage(key, data)
        redis.set key, data.to_json
      end

      def get_report(key)
        data = redis.get key
        data ? JSON.parse(data) : {}
      end

      def store_map(key, values)
        unless values.empty?
          existing = redis.hgetall(key)
          # in redis all keys are strings
          values = Hash[values.map { |k, val| [k.to_s, val] }]
          values.merge!(existing) { |_k, old_v, new_v| old_v.to_i + new_v.to_i }
          redis.mapped_hmset(key, values)
          redis.expire(key, @ttl) if @ttl
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
