# frozen_string_literal: true

require "forwardable"
require_relative "base"
require_relative "../../storage/session"

module Coverband
  module Adapters
    module TrackerStorage
      ###
      # A tracker stored as one document: metadata and payload written together
      # and reverted together.
      #
      # Used for every cache backed tracker, and on Redis for the trackers whose
      # merge is additive. The tracker supplies the merge itself, since only it
      # knows whether two values combine by taking the later timestamp or by
      # summing counters.
      ###
      class DocumentRepository < Base
        extend Forwardable

        # the session owns the protocol; this class only decides what a tracker
        # is allowed to ask for and normalizes what comes back
        def_delegators :@session, :record, :delete_entry, :reset, :tracking_since,
          :data_loss, :pending_size

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
          # Redis hgetall hands back strings; JSON parsing doesn't. Normalizing
          # here keeps the two implementations interchangeable for callers.
          @session.entries.each_with_object({}) do |(key, value), normalized|
            normalized[key.to_s] = value.is_a?(String) ? value : value.to_s
          end
        end

        def pointer_session
          @session
        end

        def newly_tombstoned
          @session.newly_tombstoned
        end

        def generation
          @session.generation_token
        end

        # the session keeps unconfirmed deltas, so callers hand theirs over
        def retains_pending?
          true
        end
      end
    end
  end
end
