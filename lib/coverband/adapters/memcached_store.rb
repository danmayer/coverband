# frozen_string_literal: true

module Coverband
  module Adapters
    class MemcachedStore < Base
      STORAGE_FORMAT_VERSION = "coverband_3_2"

      attr_reader :memcached_namespace

      def initialize(memcached, opts = {})
        super()
        @memcached = memcached
        @memcached_namespace = opts[:memcached_namespace]
        @format_version = STORAGE_FORMAT_VERSION
        @keys = {}
        Coverband::TYPES.each do |type|
          @keys[type] = [@format_version, @memcached_namespace, type].compact.join(".")
        end
      end

      def clear!
        Coverband::TYPES.each do |type|
          @memcached.delete(type_base_key(type))
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
        @memcached.read(base_key) ? @memcached.read(base_key).bytesize : "N/A"
      end

      def type=(type)
        super
        reset_base_key
      end

      def coverage(local_type = nil, opts = {})
        local_type ||= opts.key?(:override_type) ? opts[:override_type] : type
        data = memcached.read(type_base_key(local_type))
        data = data ? JSON.parse(data) : {}
        data.delete_if { |file_path, file_data| file_hash(file_path) != file_data["file_hash"] } unless opts[:skip_hash_check]
        data
      end

      def save_report(report)
        data = report.dup
        data = merge_reports(data, coverage(nil, skip_hash_check: true))
        save_coverage(data)
      end

      def raw_store
        raise NotImplementedError, "MemcachedStore doesn't support raw_store"
      end

      attr_reader :memcached

      private

      def reset_base_key
        @base_key = nil
      end

      def base_key
        @base_key ||= [@format_version, @memcached_namespace, type].compact.join(".")
      end

      def type_base_key(local_type)
        @keys[local_type]
      end

      def save_coverage(data, local_type = nil)
        local_type ||= type
        key = type_base_key(local_type)
        memcached.write(key, data.to_json)
      end
    end
  end
end
