# frozen_string_literal: true

require "json"
require_relative "../storage/target"
require_relative "../storage/session"
require_relative "tracker_storage/cache"
require_relative "session_coverage"

module Coverband
  module Adapters
    ###
    # Stores coverage in any ActiveSupport::Cache::Store, which covers Redis,
    # Memcached, files, and (through Solid Cache) Postgres, MySQL, and SQLite
    # with one adapter instead of one per backend.
    #
    # Coverage counts are additive, so a lost update can't be repaired by
    # writing again: the merge protocol in Coverband::Storage::Session is what
    # makes retry safe. See docs/active_support_cache_adapter_plan.md.
    #
    # The cache target may be given lazily because Rails.cache does not exist
    # while config/coverband.rb is loading:
    #
    #   config.store = Coverband::Adapters::ActiveSupportCacheStore.new { Rails.cache }
    ###
    class ActiveSupportCacheStore < Base
      include SessionCoverage

      ###
      # Bumped from coverband_3_2: documents now carry their metadata, and keys
      # are generation scoped. Old keys are ignored, not migrated.
      ###
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
        @tracker_storage ||= TrackerStorage::Cache.new(target: @target, namespace: @cache_namespace,
          format_version: @format_version)
      end

      def raw_store
        raise NotImplementedError, "#{self.class.name} doesn't support raw_store, use tracker_storage"
      end

      private

      ###
      # Both types are built together on first use. Reporting one type would
      # otherwise allocate the other's keys later, at an unpredictable moment.
      ###
      def storage_target
        @target
      end

      def coverage_key_base(local_type)
        key_base(local_type)
      end

      def key_base(local_type)
        [@format_version, @cache_namespace, "coverage", local_type].compact.join(".")
      end
    end
  end
end
