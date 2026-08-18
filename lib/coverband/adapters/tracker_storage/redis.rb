# frozen_string_literal: true

require_relative "document_repository"
require_relative "redis_hash_repository"
require_relative "../../storage/redis_target"

module Coverband
  module Adapters
    module TrackerStorage
      ###
      # Builds tracker repositories over a Redis client, choosing the layout by
      # merge semantics rather than by backend.
      #
      # Idempotent presence trackers keep native hashes: per field writes are
      # never reverted, which no whole document protocol can match.
      #
      # Additive trackers can't, because a Redis hash co-writes metadata but
      # doesn't co-revert it. A stale multi-field HSET leaves another writer's
      # field in place while wiping the metadata that recorded it, so that
      # writer sees no watermark and applies its delta a second time.
      ###
      class Redis
        def initialize(redis:, namespace:, format_version:)
          @target = Storage::RedisTarget.new(redis)
          @namespace = namespace
          @format_version = format_version
        end

        def for(name, merger:, idempotent: true, logger: nil, on_generation_change: nil)
          key_base = [@format_version, @namespace, "tracker", name].compact.join(".")

          if idempotent
            RedisHashRepository.new(
              target: @target,
              key_base: key_base,
              logger: logger,
              on_generation_change: on_generation_change
            )
          else
            DocumentRepository.new(
              target: @target,
              key_base: key_base,
              merger: merger,
              logger: logger,
              on_generation_change: on_generation_change
            )
          end
        end
      end
    end
  end
end
