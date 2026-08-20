# frozen_string_literal: true

module Coverband
  module Storage
    # Describes why a generation coordinator changed or confirmed its token.
    # Consumers can make lifecycle decisions without knowing how the pointer
    # protocol classified the transition.
    class GenerationChange < Struct.new(:cause, :previous_token, :authoritative_token, keyword_init: true)
      INITIALIZATION = :initialization
      CONFIRMATION = :confirmation
      OPERATOR_RESET = :operator_reset
      POINTER_EVICTION = :pointer_eviction
      DOCUMENT_EVICTION = :document_eviction
      INITIALIZATION_RACE = :initialization_race

      CAUSES = [
        INITIALIZATION,
        CONFIRMATION,
        OPERATOR_RESET,
        POINTER_EVICTION,
        DOCUMENT_EVICTION,
        INITIALIZATION_RACE
      ].freeze

      def initialize(cause:, previous_token:, authoritative_token:)
        raise ArgumentError, "unknown generation change cause: #{cause.inspect}" unless CAUSES.include?(cause)

        super(
          cause: cause,
          previous_token: immutable_token(previous_token),
          authoritative_token: immutable_token(authoritative_token)
        )
        freeze
      end

      private

      def immutable_token(token)
        token&.dup&.freeze
      end
    end
  end
end
