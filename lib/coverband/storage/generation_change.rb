# frozen_string_literal: true

module Coverband
  module Storage
    # Describes why a generation coordinator changed or confirmed its token.
    # Consumers can make lifecycle decisions without knowing how the pointer
    # protocol classified the transition.
    class GenerationChange
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

      attr_reader :cause, :previous_token, :authoritative_token

      def initialize(cause:, previous_token:, authoritative_token:)
        raise ArgumentError, "unknown generation change cause: #{cause.inspect}" unless CAUSES.include?(cause)

        @cause = cause
        # Do not hand callbacks the coordinator's mutable token strings. The
        # event itself is immutable; its token copies remain ordinary strings so
        # newer Rubies do not intern a fresh frozen string on every confirmation.
        @previous_token = previous_token&.dup
        @authoritative_token = authoritative_token&.dup
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          cause == other.cause &&
          previous_token == other.previous_token &&
          authoritative_token == other.authoritative_token
      end

      alias_method :eql?, :==

      def hash
        [self.class, cause, previous_token, authoritative_token].hash
      end
    end
  end
end
