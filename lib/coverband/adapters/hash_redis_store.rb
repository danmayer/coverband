# frozen_string_literal: true

require "securerandom"

module Coverband
  module Adapters
    class HashRedisStore < Base
      FILE_KEY = "file"
      FILE_LENGTH_KEY = "file_length"
      META_DATA_KEYS = [DATA_KEY, FIRST_UPDATED_KEY, LAST_UPDATED_KEY, FILE_HASH].freeze
      ###
      # This key isn't related to the coverband version, but to the internal format
      # used to store data to redis. It is changed only when breaking changes to our
      # redis format are required.
      ###
      REDIS_STORAGE_FORMAT_VERSION = "coverband_hash_4_0"

      JSON_PAYLOAD_EXPIRATION = 5 * 60

      attr_reader :redis_namespace

      def initialize(redis, opts = {})
        super()
        @redis_namespace = opts[:redis_namespace]
        @save_report_batch_size = opts[:save_report_batch_size] || 100
        @format_version = REDIS_STORAGE_FORMAT_VERSION
        @redis = redis
        raise "HashRedisStore requires redis >= 2.6.0" unless supported?

        @ttl = opts[:ttl]
        @relative_file_converter = opts[:relative_file_converter] || Utils::RelativeFileConverter
      end

      def supported?
        Gem::Version.new(@redis.info["redis_version"]) >= Gem::Version.new("2.6.0")
      rescue Redis::CannotConnectError => e
        Coverband.configuration.logger.info "Redis is not available (#{e}), Coverband not configured"
        Coverband.configuration.logger.info "If this is a setup task like assets:precompile feel free to ignore"
      end

      def clear!
        old_type = type
        Coverband::TYPES.each do |type|
          self.type = type
          file_keys = files_set
          @redis.del(*file_keys) if file_keys.any?
          @redis.del(files_key)
          @redis.del(files_key(type))
        end
        self.type = old_type
      end

      def clear_file!(file)
        file_hash = file_hash(file)
        relative_path_file = @relative_file_converter.convert(file)
        Coverband::TYPES.each do |type|
          @redis.del(key(relative_path_file, type, file_hash: file_hash))
        end
        @redis.srem(files_key, relative_path_file)
      end

      def save_report(report)
        report_time = Time.now.to_i
        updated_time = (type == Coverband::EAGER_TYPE) ? nil : report_time
        keys = []
        report.each_slice(@save_report_batch_size) do |slice|
          files_data = slice.map do |(file, data)|
            relative_file = @relative_file_converter.convert(file)
            file_hash = file_hash(relative_file)
            key = key(relative_file, file_hash: file_hash)
            keys << key
            script_input(
              key: key,
              file: relative_file,
              file_hash: file_hash,
              data: data,
              report_time: report_time,
              updated_time: updated_time
            )
          end
          next unless files_data.any?

          arguments_key = [@redis_namespace, SecureRandom.uuid].compact.join(".")
          @redis.set(arguments_key, {ttl: @ttl, files_data: files_data}.to_json, ex: JSON_PAYLOAD_EXPIRATION)
          @redis.evalsha(hash_incr_script, [arguments_key], [report_time])
        end
        @redis.sadd(files_key, keys) if keys.any?
      end

      # NOTE: This method should be used for full coverage or filename coverage look ups
      # When paging code should use coverage_for_types and pull eager and runtime together as matched pairs
      def coverage(local_type = nil, opts = {})
        page_size = opts[:page_size] || 250
        files_set = if opts[:page]
          raise "call coverage_for_types with paging"
        elsif opts[:filename]
          type_key_prefix = key_prefix(local_type)
          # NOTE: a better way to extract filename from key would be better
          files_set(local_type).select do |cache_key|
            cache_key.sub(type_key_prefix, "").match(short_name(opts[:filename]))
          end || {}
        else
          files_set(local_type)
        end

        # below uses batches with a sleep in between to avoid overloading redis
        files_set = files_set.each_slice(page_size).flat_map do |key_batch|
          sleep(0.01 * rand(1..10))
          @redis.pipelined do |pipeline|
            key_batch.each do |key|
              pipeline.hgetall(key)
            end
          end
        end

        files_set.each_with_object({}) do |data_from_redis, hash|
          add_coverage_for_file(data_from_redis, hash)
        end
      end

      def split_coverage(types, coverage_cache, options = {})
        if types.is_a?(Array) && !options[:filename] && options[:page]
          data = coverage_for_types(types, options)
          coverage_cache[Coverband::RUNTIME_TYPE] = data[Coverband::RUNTIME_TYPE]
          coverage_cache[Coverband::EAGER_TYPE] = data[Coverband::EAGER_TYPE]
          data
        else
          super
        end
      end

      def coverage_for_types(_types, opts = {})
        page_size = opts[:page_size] || 250
        hash_data = {}

        runtime_file_set = files_set(Coverband::RUNTIME_TYPE)
        @cached_file_count = runtime_file_set.length
        runtime_file_set = runtime_file_set.each_slice(page_size).to_a[opts[:page] - 1] || []

        hash_data[Coverband::RUNTIME_TYPE] = runtime_file_set.each_slice(page_size).flat_map do |key_batch|
          @redis.pipelined do |pipeline|
            key_batch.each do |key|
              pipeline.hgetall(key)
            end
          end
        end

        # NOTE: This is kind of hacky, we find all the matching eager loading data
        # for current page of runtime data.
        eager_key_pre = key_prefix(Coverband::EAGER_TYPE)
        runtime_key_pre = key_prefix(Coverband::RUNTIME_TYPE)
        matched_file_set = runtime_file_set.map do |runtime_key|
          runtime_key.sub(runtime_key_pre, eager_key_pre)
        end

        hash_data[Coverband::EAGER_TYPE] = matched_file_set.each_slice(page_size).flat_map do |key_batch|
          @redis.pipelined do |pipeline|
            key_batch.each do |key|
              pipeline.hgetall(key)
            end
          end
        end

        hash_data[Coverband::RUNTIME_TYPE] = hash_data[Coverband::RUNTIME_TYPE].each_with_object({}) do |data_from_redis, hash|
          add_coverage_for_file(data_from_redis, hash)
        end
        hash_data[Coverband::EAGER_TYPE] = hash_data[Coverband::EAGER_TYPE].each_with_object({}) do |data_from_redis, hash|
          add_coverage_for_file(data_from_redis, hash)
        end
        hash_data
      end

      def short_name(filename)
        filename.sub(/^#{Coverband.configuration.root}/, ".")
          .gsub(%r{^\./}, "")
      end

      def file_count(local_type = nil)
        files_set(local_type).count { |filename| !Coverband.configuration.ignore.any? { |i| filename.match(i) } }
      end

      def cached_file_count
        @cached_file_count ||= file_count(Coverband::RUNTIME_TYPE)
      end

      def raw_store
        @redis
      end

      def size
        "not available"
      end

      def size_in_mib
        "not available"
      end

      private

      def add_coverage_for_file(data_from_redis, hash)
        return if data_from_redis.empty?

        file = data_from_redis[FILE_KEY]
        return unless file_hash(file) == data_from_redis[FILE_HASH]

        data = coverage_data_from_redis(data_from_redis)
        timedata = coverage_time_data_from_redis(data_from_redis)
        hash[file] = data_from_redis.select do |meta_data_key, _value|
          META_DATA_KEYS.include?(meta_data_key)
        end.merge!("data" => data, "timedata" => timedata)
        hash[file][LAST_UPDATED_KEY] =
          (hash[file][LAST_UPDATED_KEY].nil? || hash[file][LAST_UPDATED_KEY] == "") ? nil : hash[file][LAST_UPDATED_KEY].to_i
        hash[file].merge!(LAST_UPDATED_KEY => hash[file][LAST_UPDATED_KEY],
          FIRST_UPDATED_KEY => hash[file][FIRST_UPDATED_KEY].to_i)
      end

      def coverage_data_from_redis(data_from_redis)
        max = data_from_redis[FILE_LENGTH_KEY].to_i - 1
        Array.new(max + 1) do |index|
          line_coverage = data_from_redis[index.to_s]
          line_coverage&.to_i
        end
      end

      def coverage_time_data_from_redis(data_from_redis)
        max = data_from_redis[FILE_LENGTH_KEY].to_i - 1
        Array.new(max + 1) do |index|
          unixtime = data_from_redis["#{index}_last_posted"]
          unixtime.nil? ? nil : Time.at(unixtime.to_i)
        end
      end

      def script_input(key:, file:, file_hash:, data:, report_time:, updated_time:)
        coverage_data = data.each_with_index.each_with_object({}) do |(coverage, index), hash|
          hash[index] = coverage if coverage
        end
        meta = {
          first_updated_at: report_time,
          file: file,
          file_hash: file_hash,
          file_length: data.length,
          hash_key: key
        }
        meta[:last_updated_at] = updated_time if updated_time
        {
          hash_key: key,
          meta: meta,
          coverage: coverage_data
        }
      end

      def hash_incr_script
        @hash_incr_script ||= @redis.script(:load, lua_script_content)
      end

      def lua_script_content
        File.read(File.join(
          File.dirname(__FILE__), "../../../lua/lib/persist-coverage.lua"
        ))
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

      def key(file, local_type = nil, file_hash:)
        [key_prefix(local_type), file, file_hash].join(".")
      end

      def key_prefix(local_type = nil)
        local_type ||= type
        [@format_version, @redis_namespace, local_type].compact.join(".")
      end
    end
  end
end
