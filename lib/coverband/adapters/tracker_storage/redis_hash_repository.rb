# frozen_string_literal: true

require_relative "base"
require_relative "../../storage/generation"
require_relative "../../storage/generation_lifecycle"
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
        include Storage::GenerationLifecycle
        include Storage::ReadFallback

        STARTED_AT_FIELD = "__coverband_started_at__"

        def initialize(target:, key_base:, logger: nil, grace_seconds: 1200, on_generation_change: nil)
          @target = target
          @key_base = key_base
          @logger = logger
          @on_generation_change = on_generation_change
          @generation = Storage::Generation.new(target, "#{key_base}.pointer", grace_seconds: grace_seconds)
          @token = nil
        end

        def pointer_session
          self
        end

        # no pending deltas here, but a primed pointer is still cycle state
        def discard_pending!
          clear_primed_pointer!
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
          operation do
            token = @generation.reset!(current_token: @token)
            next false unless token

            @token = token
            @started_at_set = false
            @on_generation_change&.call(:reset)
            true
          end
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

        def on_generation_changed(result)
          @started_at_set = false
          @on_generation_change&.call(result.pointer_missing ? :eviction : :reset)
        end
      end
    end
  end
end
