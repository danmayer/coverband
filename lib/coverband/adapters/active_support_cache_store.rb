# frozen_string_literal: true

require "json"
require_relative "../storage/target"
require_relative "../storage/session"
require_relative "tracker_storage/cache"

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
      ###
      # Bumped from coverband_3_2: documents now carry their metadata, and keys
      # are generation scoped. Old keys are ignored, not migrated.
      ###
      STORAGE_FORMAT_VERSION = "coverband_cache_4_0"

      # coverage deltas are large, so they get a tighter pending bound than the
      # trackers do
      COVERAGE_MAX_ENTRIES = 2

      attr_reader :cache_namespace

      def initialize(cache = nil, opts = {}, &block)
        super()
        @target = Storage::Target.new(cache, &block)
        @cache_namespace = opts[:cache_namespace] || opts[:memcached_namespace] ||
          opts[:redis_namespace] || Coverband.configuration.redis_namespace
        @format_version = self.class::STORAGE_FORMAT_VERSION
        @sessions = {}
        @ttl = opts[:ttl]
      end

      def persistent_coverage?
        true
      end

      def tracker_storage
        @tracker_storage ||= TrackerStorage::Cache.new(target: @target, namespace: @cache_namespace,
          format_version: @format_version)
      end

      def clear!
        Coverband::TYPES.each { |type| session_for(type).reset }
        @cached_file_count = nil
      end

      def clear_file!(filename)
        relative = Utils::RelativeFileConverter.convert(filename)
        Coverband::TYPES.each do |type|
          session_for(type).delete_entry(relative)
          session_for(type).delete_entry(filename)
        end
        @cached_file_count = nil
      end

      def size
        raw = @target.read(session_for(type).send(:data_key))
        raw&.to_s&.bytesize
      end

      def coverage(local_type = nil, opts = {})
        local_type ||= opts.key?(:override_type) ? opts[:override_type] : type
        data = session_for(local_type).entries
        data = data.dup
        unless opts[:skip_hash_check]
          data.delete_if { |file_path, file_data| file_hash(file_path) != file_data["file_hash"] }
        end
        data
      end

      ###
      # The report is enqueued as an immutable delta and merged inside the
      # session. Expanding it here, once, is deliberate: re-expanding on retry
      # would hand an old delta a fresh timestamp and let it slip past a
      # tombstone recorded in between.
      ###
      def save_report(report)
        session_for(type).record(expand_report(report.dup))
        @cached_file_count = nil
      end

      def save_coverage(report, local_type = nil)
        session_for(local_type || type).record(expand_report(report.dup))
      end

      def raw_store
        raise NotImplementedError, "#{self.class.name} doesn't support raw_store, use tracker_storage"
      end

      def data_loss
        Coverband::TYPES.map { |type| session_for(type).data_loss }.compact.first
      end

      ###
      # Unconfirmed reports are held so a conflicting write can be repaired next
      # cycle. This gives that up in exchange for the memory, and is only for
      # benchmarks and shutdown paths.
      ###
      def discard_pending!
        Coverband::TYPES.each { |type| session_for(type).discard_pending! }
      end

      def file_count
        coverage(Coverband::RUNTIME_TYPE, skip_hash_check: true).keys.length
      end

      def type=(type)
        super
        @cached_file_count = nil
      end

      private

      ###
      # Both types are built together on first use. Reporting one type would
      # otherwise allocate the other's keys later, at an unpredictable moment.
      ###
      def session_for(local_type)
        local_type ||= type
        Coverband::TYPES.each { |session_type| build_session(session_type) }
        @sessions[local_type] ||= build_session(local_type)
      end

      def build_session(local_type)
        @sessions[local_type] ||= Storage::Session.new(
          target: @target,
          key_base: key_base(local_type),
          merger: coverage_merger,
          logger: Coverband.configuration.logger,
          max_entries: COVERAGE_MAX_ENTRIES,
          grace_seconds: grace_seconds
        )
      end

      ###
      # Coverage payloads merge by summing line hits, which is why the applied
      # sequence guard exists: applying the same delta twice would inflate the
      # counts rather than being a no-op.
      ###
      def coverage_merger
        @coverage_merger ||= lambda do |doc, delta|
          incoming = delta.payload.reject do |file, _data|
            doc.tombstoned?(file, delta.tombstone_epoch)
          end
          doc.payload.replace(merge_reports(incoming.dup, doc.payload, skip_expansion: true))
        end
      end

      def grace_seconds
        Coverband.configuration.background_reporting_sleep_seconds * 2
      rescue
        1200
      end

      def key_base(local_type)
        [@format_version, @cache_namespace, "coverage", local_type].compact.join(".")
      end
    end
  end
end
