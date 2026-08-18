# frozen_string_literal: true

require_relative "document_repository"

module Coverband
  module Adapters
    module TrackerStorage
      ###
      # Builds tracker repositories over an ActiveSupport::Cache store.
      #
      # A cache has no per field operations, so every tracker is one document
      # and every document uses applied sequences. Idempotent trackers still
      # need them: not for retry safety, but to notice that a stale whole
      # document write erased a key. Without that signal the losing process's
      # permanent local dedupe would keep it from ever being re-enqueued.
      ###
      class Cache
        def initialize(target:, namespace:, format_version:)
          @target = target
          @namespace = namespace
          @format_version = format_version
        end

        def for(name, merger:, idempotent: true, logger: nil, on_generation_change: nil)
          DocumentRepository.new(
            target: @target,
            key_base: [@format_version, @namespace, "tracker", name].compact.join("."),
            merger: merger,
            logger: logger,
            on_generation_change: on_generation_change
          )
        end
      end
    end
  end
end
