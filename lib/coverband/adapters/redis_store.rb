# frozen_string_literal: true

require_relative "../storage/redis_target"
require_relative "../storage/session"
require_relative "tracker_storage/redis"

module Coverband
  module Adapters
    ###
    # RedisStore store a merged coverage file to redis
    ###
    class RedisStore < Base
      ###
      # This key isn't related to the coverband version, but to the internal format
      # used to store data to redis. It is changed only when breaking changes to our
      # redis format are required.
      #
      # Bumped from coverband_3_2 for 7.0: coverage documents now carry the
      # metadata the merge protocol needs, and keys are generation scoped. There
      # is no migration; old keys are ignored.
      ###
      REDIS_STORAGE_FORMAT_VERSION = "coverband_5_0"

      COVERAGE_MAX_ENTRIES = 2

      attr_reader :redis_namespace

      def initialize(redis, opts = {})
        super()
        @redis = redis
        @ttl = opts[:ttl]
        @redis_namespace = opts[:redis_namespace]
        @format_version = REDIS_STORAGE_FORMAT_VERSION
        @sessions = {}
      end

      def persistent_coverage?
        true
      end

      def tracker_storage
        sync_target
        @tracker_storage ||= TrackerStorage::Redis.new(redis: @redis, namespace: @redis_namespace,
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
        raw = @redis.get(session_for(type).send(:data_key))
        raw&.bytesize
      end

      def type=(type)
        super
        @cached_file_count = nil
      end

      def coverage(local_type = nil, opts = {})
        local_type ||= opts.key?(:override_type) ? opts[:override_type] : type
        data = session_for(local_type).entries.dup
        unless opts[:skip_hash_check]
          data.delete_if { |file_path, file_data| file_hash(file_path) != file_data["file_hash"] }
        end
        data
      end

      ###
      # Coverage counts are additive, so the old read-merge-write could silently
      # drop a process's contribution when two reported at once. The report is
      # enqueued as an immutable delta and applied under a per writer sequence,
      # which makes the retry that repairs the conflict safe to perform.
      ###
      def save_report(report)
        session_for(type).record(expand_report(report.dup))
        @cached_file_count = nil
      end

      def save_coverage(report, local_type = nil)
        session_for(local_type || type).record(expand_report(report.dup))
      end

      def raw_store
        @redis
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

      private

      attr_reader :redis

      ###
      # The client can be swapped after construction, and a different client is
      # a different database: cached generation tokens and unconfirmed deltas
      # from the old one would be meaningless against the new one.
      ###
      def sync_target
        return @target if @target && @target.redis.equal?(@redis)

        @sessions.clear
        @tracker_storage = nil
        @target = Storage::RedisTarget.new(@redis)
      end

      ###
      # Both types are built together on first use. Reporting one type would
      # otherwise allocate the other's keys later, at an unpredictable moment.
      ###
      def session_for(local_type)
        local_type ||= type
        sync_target
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
        [@format_version, @redis_namespace, "coverage", local_type].compact.join(".")
      end
    end
  end
end
