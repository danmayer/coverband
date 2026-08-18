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
    # Including classes provide @generation and may define
    # #on_generation_changed(result) to react to a new token.
    ###
    module GenerationLifecycle
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
          # only needed for the sweep above; holding it would retain a copy of
          # the pointer document between reports
          @pointer = nil
        end
      end

      def sync_generation
        return if @synced

        @synced = true
        result = @generation.resolve
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
