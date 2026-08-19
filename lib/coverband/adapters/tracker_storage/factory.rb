# frozen_string_literal: true

require_relative "document_repository"
require_relative "redis_hash_repository"
require_relative "../../storage/redis_target"

module Coverband
  module Adapters
    module TrackerStorage
      ###
      # Builds tracker repositories, choosing the layout by merge semantics
      # rather than by backend.
      #
      # Idempotent presence trackers keep native Redis hashes where the backend
      # has them: a field written by one process is never reverted by another's
      # write, which no whole document protocol can match.
      #
      # Everything else is a document. Additive trackers can never use the hash,
      # because a hash co-writes metadata without co-reverting it: a stale
      # multi-field HSET leaves another writer's field in place while wiping the
      # metadata that recorded it, so that writer applies its delta twice. On a
      # cache, idempotent trackers are documents too, and still need applied
      # sequences -- not for retry safety, but to notice a stale write erased a
      # key, which a permanent local dedupe would otherwise never re-enqueue.
      ###
      class Factory
        def self.redis(redis:, namespace:, format_version:)
          new(target: Storage::RedisTarget.new(redis), namespace: namespace,
            format_version: format_version, native_hashes: true)
        end

        def self.cache(target:, namespace:, format_version:)
          new(target: target, namespace: namespace, format_version: format_version)
        end

        def initialize(target:, namespace:, format_version:, native_hashes: false)
          @target = target
          @namespace = namespace
          @format_version = format_version
          @native_hashes = native_hashes
        end

        def for(name, merger:, idempotent: true, logger: nil, on_generation_change: nil)
          key_base = [@format_version, @namespace, "tracker", name].compact.join(".")

          if @native_hashes && idempotent
            RedisHashRepository.new(target: @target, key_base: key_base,
              logger: logger, on_generation_change: on_generation_change)
          else
            DocumentRepository.new(target: @target, key_base: key_base, merger: merger,
              logger: logger, on_generation_change: on_generation_change)
          end
        end
      end
    end
  end
end
