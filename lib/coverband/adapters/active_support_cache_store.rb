# frozen_string_literal: true

require "json"
require_relative "../storage/target"
require_relative "../storage/session"
require_relative "tracker_storage/factory"
require_relative "session_coverage"

module Coverband
  module Adapters
    ###
    # Stores coverage in any ActiveSupport::Cache::Store: Redis, Memcached,
    # files, and through Solid Cache, Postgres, MySQL, and SQLite -- one adapter
    # instead of one per backend. See docs/active_support_cache_adapter_plan.md.
    #
    # The cache target may be given lazily, because Rails.cache does not exist
    # while config/coverband.rb is loading:
    #
    #   config.store = Coverband::Adapters::ActiveSupportCacheStore.new { Rails.cache }
    ###
    class ActiveSupportCacheStore < Base
      include SessionCoverage

      # bumped from coverband_3_2: documents carry their metadata and keys are
      # generation scoped, so old keys are ignored rather than migrated
      STORAGE_FORMAT_VERSION = "coverband_cache_4_0"

      attr_reader :cache_namespace

      def initialize(cache = nil, opts = {}, &block)
        super()
        @target = Storage::Target.new(cache, &block)
        @cache_namespace = opts[:cache_namespace] || opts[:memcached_namespace] ||
          opts[:redis_namespace] || Coverband.configuration.redis_namespace
        @format_version = self.class::STORAGE_FORMAT_VERSION
        @ttl = opts[:ttl]
      end

      def tracker_storage
        @tracker_storage ||= TrackerStorage::Factory.cache(target: @target, namespace: @cache_namespace,
          format_version: @format_version)
      end

      private

      def storage_target
        @target
      end

      def coverage_key_base(local_type)
        [@format_version, @cache_namespace, "coverage", local_type].compact.join(".")
      end
    end
  end
end
