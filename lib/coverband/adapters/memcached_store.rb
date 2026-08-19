# frozen_string_literal: true

require_relative "active_support_cache_store"

module Coverband
  module Adapters
    ###
    # Deprecated: MemcachedStore was already an ActiveSupport::Cache adapter in
    # everything but name, so it is now a thin subclass of the generic one.
    #
    # memcached_namespace is translated to the new namespace option, and the
    # reader is kept, so existing configuration keeps working. Stored data is
    # not migrated: the document format changed in 7.0 and coverage starts fresh.
    ###
    class MemcachedStore < ActiveSupportCacheStore
      attr_reader :memcached_namespace

      def initialize(memcached, opts = {})
        Coverband.configuration.logger&.info(
          "Coverband: MemcachedStore is deprecated, use " \
          "Coverband::Adapters::ActiveSupportCacheStore, which supports the same " \
          "memcached store plus Redis, files, and Solid Cache"
        )
        @memcached_namespace = opts[:memcached_namespace]
        super
      end

      def memcached
        @target.target
      end
    end
  end
end
