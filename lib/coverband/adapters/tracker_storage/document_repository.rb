# frozen_string_literal: true

require "forwardable"
require_relative "base"
require_relative "../../storage/session"

module Coverband
  module Adapters
    module TrackerStorage
      ###
      # A tracker stored as one document: metadata and payload written together
      # and reverted together. Every cache backed tracker, plus the additive ones
      # on Redis. The tracker supplies the merge, since only it knows whether two
      # values combine by later timestamp or by summing.
      ###
      class DocumentRepository < Base
        extend Forwardable

        # the session owns the protocol; this decides what a tracker may ask for
        def_delegators :@session, :record, :delete_entry, :reset, :tracking_since,
          :data_loss, :pending_size, :newly_tombstoned
        def_delegator :@session, :generation_token, :generation

        def initialize(target:, key_base:, merger:, logger: nil, on_generation_change: nil, session_options: {})
          @session = Storage::Session.new(
            target: target,
            key_base: key_base,
            merger: merger,
            logger: logger,
            on_generation_change: on_generation_change,
            **session_options
          )
        end

        def entries
          # Redis hgetall hands back strings and JSON parsing does not, so the
          # two layouts would otherwise not be interchangeable for callers
          @session.entries.each_with_object({}) do |(key, value), normalized|
            normalized[key.to_s] = value.is_a?(String) ? value : value.to_s
          end
        end

        def pointer_session
          @session
        end

        def retains_pending?
          true
        end
      end
    end
  end
end
