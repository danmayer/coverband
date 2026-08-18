# frozen_string_literal: true

require_relative "../storage/redis_target"
require_relative "../storage/session"
require_relative "tracker_storage/redis"
require_relative "session_coverage"

module Coverband
  module Adapters
    ###
    # RedisStore store a merged coverage file to redis
    ###
    class RedisStore < Base
      include SessionCoverage

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

      attr_reader :redis_namespace

      def initialize(redis, opts = {})
        super()
        @redis = redis
        @ttl = opts[:ttl]
        @redis_namespace = opts[:redis_namespace]
        @format_version = REDIS_STORAGE_FORMAT_VERSION
      end

      def tracker_storage
        sync_target
        @tracker_storage ||= TrackerStorage::Redis.new(redis: @redis, namespace: @redis_namespace,
          format_version: @format_version)
      end

      def raw_store
        @redis
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

        sessions.clear
        @tracker_storage = nil
        @target = Storage::RedisTarget.new(@redis)
      end

      ###
      # Both types are built together on first use. Reporting one type would
      # otherwise allocate the other's keys later, at an unpredictable moment.
      ###
      def storage_target
        sync_target
      end

      def coverage_key_base(local_type)
        key_base(local_type)
      end

      def key_base(local_type)
        [@format_version, @redis_namespace, "coverage", local_type].compact.join(".")
      end
    end
  end
end
