# frozen_string_literal: true

require_relative "base"
require_relative "../../storage/generation"

module Coverband
  module Adapters
    module TrackerStorage
      ###
      # Presence trackers on Redis, kept on native hash operations.
      #
      # Their merge is max(timestamp), so re-applying a field is a no-op and
      # there is nothing to detect: a field written by one process is never
      # reverted by another's write. That is strictly stronger than any whole
      # document protocol, so these trackers keep HSET and HDEL.
      #
      # The one thing HDEL can't do is stop a delete from being undone by an
      # HSET that was already queued before it, which is why single key clears
      # are documented as best effort here.
      ###
      class RedisHashRepository < Base
        STARTED_AT_FIELD = "__coverband_started_at__"

        def initialize(target:, key_base:, logger: nil, grace_seconds: 1200, on_generation_change: nil)
          @target = target
          @key_base = key_base
          @logger = logger
          @on_generation_change = on_generation_change
          @generation = Storage::Generation.new(target, "#{key_base}.pointer", grace_seconds: grace_seconds)
          @token = nil
        end

        def entries
          operation do
            @target.hgetall(data_key).reject { |field, _value| field == STARTED_AT_FIELD }
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

        ###
        # HDEL can't stop an HSET that was queued before it, so a key observed
        # by another process just before the delete can come back with no
        # post-delete observation behind it. Best effort, and documented as such.
        ###
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
            @on_generation_change&.call
            true
          end
        end

        def tracking_since
          operation do
            value = @target.hgetall(data_key)[STARTED_AT_FIELD]
            value ? Time.at(value.to_i) : nil
          end
        end

        def generation
          operation { @token }
        end

        private

        def operation
          outermost = !@in_operation
          @in_operation = true
          sync_generation if outermost
          result = yield
          if outermost && @sweep_due
            @generation.sweep(@pointer)
            @sweep_due = false
          end
          result
        ensure
          if outermost
            @in_operation = false
            @synced = false
          end
        end

        def started_at_set?
          @started_at_set ||= !@target.hgetall(data_key)[STARTED_AT_FIELD].nil?
        end

        def sync_generation
          return if @synced

          @synced = true
          result = @generation.resolve
          @pointer = result.pointer
          @sweep_due = !Array(result.pointer && result.pointer[Storage::Generation::RETIRE]).empty?

          if @token && result.token != @token
            @started_at_set = false
            @on_generation_change&.call
          end
          @token = result.token
        end

        def data_key
          "#{@key_base}.g#{@token}"
        end
      end
    end
  end
end
