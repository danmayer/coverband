# frozen_string_literal: true

require_relative "generation"

module Coverband
  module Storage
    ###
    # Shared generation bookkeeping for anything that stores data under a
    # generation scoped key.
    #
    # The rules are small but easy to get subtly wrong in two places: read the
    # pointer once per public call rather than once per helper, run the delayed
    # cleanup sweep with the pointer already in hand, and drop the parsed
    # pointer afterwards so it is not retained between reports.
    #
    # The coupling is deliberate but has to be written down, because a mixin
    # reaching into an includer's instance variables is otherwise guesswork.
    #
    # Required of the includer, set before any operation runs:
    #   @generation  a Storage::Generation for this document
    #   @key_base    the key prefix the generation token is appended to
    #
    # Owned entirely by this module, and not to be touched by the includer:
    #   @token       the authoritative generation token
    #   @in_operation, @synced, @pointer, @sweep_due, @primed_pointer
    #
    # Optional hooks, each called at most once per sync:
    #   #on_generation_initialized(result)  no token was held before
    #   #on_generation_confirmed(result)    the held token is still authoritative
    #   #on_generation_changed(result)      a different token is now authoritative
    ###
    module GenerationLifecycle
      def generation
        operation { @token }
      end

      def pointer_key
        @generation.key
      end

      # a primed pointer older than this is discarded and read fresh instead
      PRIMED_POINTER_TTL = 5

      ###
      # Hands over a pointer value fetched in a batch, for the reporting cycle
      # that fetched it.
      #
      # It expires, and that matters: a session that does not report in the
      # cycle would otherwise hold the primed value indefinitely, and a reset in
      # the meantime would send its eventual write into a retired generation
      # where nothing can read it.
      ###
      def prime_pointer(raw)
        @primed_pointer = raw
        @primed_at = Time.now.to_i
      end

      def clear_primed_pointer!
        @primed_pointer = nil
        @primed_at = nil
      end

      def primed_pointer
        return nil if @primed_pointer.nil?
        return nil if (Time.now.to_i - @primed_at.to_i) > PRIMED_POINTER_TTL

        @primed_pointer
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
          # only needed for the sweep above; holding it would retain a copy of
          # the pointer document between reports
          @pointer = nil
        end
      end

      def sync_generation
        return if @synced

        @synced = true
        result = @generation.resolve(primed: primed_pointer)
        @primed_pointer = nil
        @primed_at = nil
        @sweep_due = !Array(result.pointer && result.pointer[Generation::RETIRE]).empty?
        @pointer = result.pointer if @sweep_due

        if @token.nil?
          @token = result.token
          on_generation_initialized(result) if respond_to?(:on_generation_initialized, true)
          return
        end

        if result.token == @token
          on_generation_confirmed(result) if respond_to?(:on_generation_confirmed, true)
          return
        end

        on_generation_changed(result) if respond_to?(:on_generation_changed, true)
        @token = result.token
      end

      def data_key
        "#{@key_base}.g#{@token}"
      end
    end
  end
end
