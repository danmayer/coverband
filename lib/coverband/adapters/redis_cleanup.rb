# frozen_string_literal: true

module Coverband
  module Adapters
    ###
    # The narrow maintenance interface shared by Redis-backed adapters. Key
    # discovery and deletion stay here so callers never need the raw client or
    # knowledge of Coverband's Redis formats.
    ###
    class RedisCleanup
      GRACE_SECONDS = 3600
      TRACKERS = %w[ViewTracker RouteTracker TranslationTracker QueryBurstTracker].freeze

      def initialize(redis, namespace: nil)
        @redis = redis
        @namespace = namespace
      end

      def clear_legacy!
        patterns = legacy_formats.map { |format| "#{format}*" }
        [@namespace, nil].uniq.each do |namespace|
          TRACKERS.each do |tracker|
            prefix = namespace ? "#{namespace}_#{tracker}" : tracker
            patterns << "#{prefix}_tracker"
            patterns << "#{prefix}_tracker_time"
          end
        end

        delete_matching(patterns)
      end

      def clear_orphans!
        orphan_formats.sum { |format| remove_orphans(format) }
      end

      private

      ###
      # A generation is garbage only while its pointer names something else.
      # Rechecking immediately before deletion protects a generation made live
      # by a concurrent reset. Young or uncertain generations are retained.
      ###
      def remove_orphans(format)
        removed = 0

        @redis.scan_each(match: "#{format}*.g*").to_a.uniq.each do |key|
          base = key[/\A(.*)\.g[^.]*\z/, 1]
          token = key[/\.g([^.]*)\z/, 1]
          next unless base && token

          pointer = read_pointer("#{base}.pointer")
          next if pointer && pointer["token"] == token
          next if recently_written?(key)

          removed += @redis.del(key)
        end

        removed
      end

      def read_pointer(key)
        raw = @redis.get(key)
        raw ? JSON.parse(raw) : nil
      rescue JSON::ParserError
        nil
      end

      def recently_written?(key)
        idle = @redis.object("idletime", key)
        idle ? idle < GRACE_SECONDS : true
      rescue
        # If Redis cannot establish the age, retaining the key is safest.
        true
      end

      def legacy_formats
        %w[coverband_3_2 coverband_hash_3_2 coverband_hash_4_0] - current_formats
      end

      def current_formats
        [
          RedisStore::REDIS_STORAGE_FORMAT_VERSION,
          HashRedisStore::REDIS_STORAGE_FORMAT_VERSION,
          ActiveSupportCacheStore::STORAGE_FORMAT_VERSION
        ].uniq
      end

      def orphan_formats
        [
          RedisStore::REDIS_STORAGE_FORMAT_VERSION,
          HashRedisStore::REDIS_STORAGE_FORMAT_VERSION
        ].uniq
      end

      def delete_matching(patterns)
        keys = patterns.flat_map { |pattern| @redis.scan_each(match: pattern).to_a }.uniq
        keys.any? ? @redis.del(*keys) : 0
      end
    end
  end
end
