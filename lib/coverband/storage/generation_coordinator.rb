# frozen_string_literal: true

require_relative "generation"
require_relative "generation_change"

module Coverband
  module Storage
    # Owns the complete lifecycle of a generation-scoped key. Callers run work
    # through #operation and use #data_key; pointer synchronization, nested
    # operations, priming, expiry, and delayed sweeps stay behind this seam.
    class GenerationCoordinator
      PRIMED_POINTER_TTL = 5

      def initialize(target:, key_base:, grace_seconds:, on_change:,
        generation: nil, clock: -> { Time.now.to_i },
        primed_pointer_ttl: PRIMED_POINTER_TTL)
        @target = target
        @key_base = key_base
        @generation = generation || Generation.new(target, "#{key_base}.pointer", grace_seconds: grace_seconds)
        @on_change = on_change
        @clock = clock
        @primed_pointer_ttl = primed_pointer_ttl
        @token = nil
        @initialized_token = false
      end

      def token
        operation { @token }
      end

      def pointer_key
        @generation.key
      end

      def data_key
        operation { "#{@key_base}.g#{@token}" }
      end

      def prime_pointer(pointer)
        @primed_pointer = pointer
        @primed_at = @clock.call
      end

      def discard_primed_pointer!
        @primed_pointer = nil
        @primed_at = nil
      end

      def operation
        outermost = !@in_operation
        @in_operation = true
        sync if outermost
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
          @pointer = nil
        end
      end

      def reset
        operation do
          previous_token = @token
          authoritative_token = @generation.reset!(current_token: previous_token)
          next false unless authoritative_token

          @token = authoritative_token
          @initialized_token = false
          emit(GenerationChange::OPERATOR_RESET, previous_token, authoritative_token)
          true
        end
      end

      def document_evicted!
        emit(GenerationChange::DOCUMENT_EVICTION, @token, @token)
      end

      private

      def primed_pointer
        return nil if @primed_pointer.nil?
        return nil if (@clock.call - @primed_at.to_i) > @primed_pointer_ttl

        @primed_pointer
      end

      def sync
        return if @synced

        @synced = true
        result = @generation.resolve(primed: primed_pointer)
        discard_primed_pointer!
        @sweep_due = !Array(result.pointer && result.pointer[Generation::RETIRE]).empty?
        @pointer = result.pointer if @sweep_due

        if @token.nil?
          @token = result.token
          @initialized_token = result.initialized
          emit(GenerationChange::INITIALIZATION, nil, result.token)
          return
        end

        if result.token == @token
          @initialized_token = false
          emit(GenerationChange::CONFIRMATION, @token, result.token)
          return
        end

        previous_token = @token
        cause = classify_change(result, previous_token)
        @token = result.token
        @initialized_token = false
        emit(cause, previous_token, result.token)
      end

      def classify_change(result, previous_token)
        return GenerationChange::POINTER_EVICTION if result.pointer_missing

        if @initialized_token && !atomic_create_target? && !@generation.retires?(result.pointer, previous_token)
          GenerationChange::INITIALIZATION_RACE
        else
          GenerationChange::OPERATOR_RESET
        end
      end

      def atomic_create_target?
        @target.respond_to?(:atomic_create?) && @target.atomic_create?
      end

      def emit(cause, previous_token, authoritative_token)
        @on_change.call(GenerationChange.new(
          cause: cause,
          previous_token: previous_token,
          authoritative_token: authoritative_token
        ))
      end
    end
  end
end
