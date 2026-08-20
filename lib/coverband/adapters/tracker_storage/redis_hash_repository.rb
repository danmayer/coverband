# frozen_string_literal: true

require_relative "base"
require_relative "../../storage/generation_coordinator"
require_relative "../../storage/read_fallback"

module Coverband
  module Adapters
    module TrackerStorage
      ###
      # Presence trackers on Redis, kept on native hash operations.
      #
      # Their merge is max(timestamp), so re-applying a field is a no-op and a
      # field written by one process is never reverted by another's write --
      # strictly stronger than any whole document protocol, so these keep HSET
      # and HDEL. What HDEL cannot do is stop a delete being undone by an HSET
      # queued before it, which is why single key clears are best effort.
      ###
      class RedisHashRepository < Base
        include Storage::ReadFallback

        STARTED_AT_FIELD = "__coverband_started_at__"

        def initialize(target:, key_base:, logger: nil, grace_seconds: 1200, on_generation_change: nil)
          @target = target
          @logger = logger
          @on_generation_change = on_generation_change
          @generation_coordinator = Storage::GenerationCoordinator.new(
            target: target,
            key_base: key_base,
            grace_seconds: grace_seconds,
            on_change: ->(change) { handle_generation_change(change) }
          )
        end

        def pointer_session
          self
        end

        # no pending deltas here, but a primed pointer is still cycle state
        def discard_pending!
          @generation_coordinator.discard_primed_pointer!
        end

        def pointer_key
          @generation_coordinator.pointer_key
        end

        def prime_pointer(pointer)
          @generation_coordinator.prime_pointer(pointer)
        end

        def generation
          safely { @generation_coordinator.token }
        end

        def entries
          safely({}) do
            operation do
              @target.hgetall(data_key).reject { |field, _value| field == STARTED_AT_FIELD }
            end
          end
        end

        def record(delta)
          return :deferred if delta.empty?

          operation do
            values = delta.each_with_object({}) { |(key, value), hash| hash[key.to_s] = value.to_s }
            values[STARTED_AT_FIELD] = Time.now.to_i.to_s unless started_at_set?
            @target.hset(data_key, values)
            @started_at_set = true
            :written_unconfirmed
          end
        rescue => e
          @logger&.error("Coverband: #{self.class.name} failed to store, error #{e.class.name} info #{e.message}")
          :failed
        end

        # best effort: a key observed by another process just before the delete
        # can come back with no post-delete observation behind it
        def delete_entry(key)
          operation do
            @target.hdel(data_key, key.to_s)
            :written_unconfirmed
          end
        end

        def reset
          @generation_coordinator.reset
        end

        def tracking_since
          safely do
            operation do
              value = @target.hgetall(data_key)[STARTED_AT_FIELD]
              value ? Time.at(value.to_i) : nil
            end
          end
        end

        private

        def started_at_set?
          @started_at_set ||= !@target.hgetall(data_key)[STARTED_AT_FIELD].nil?
        end

        def handle_generation_change(change)
          return unless [Storage::GenerationChange::OPERATOR_RESET,
            Storage::GenerationChange::POINTER_EVICTION,
            Storage::GenerationChange::INITIALIZATION_RACE].include?(change.cause)

          @started_at_set = false
          @on_generation_change&.call(change)
        end

        def operation(&block)
          @generation_coordinator.operation(&block)
        end

        def data_key
          @generation_coordinator.data_key
        end
      end
    end
  end
end
