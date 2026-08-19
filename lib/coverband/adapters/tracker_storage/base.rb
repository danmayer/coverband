# frozen_string_literal: true

module Coverband
  module Adapters
    module TrackerStorage
      ###
      # What a tracker sees. Physical keys, generations, serialization, and the
      # applied sequence protocol all live below this line; trackers deal in
      # keys and timestamps.
      #
      # record returns a protocol state rather than an outcome, because
      # "written" and "proven durable" are different things and that difference
      # is the entire point of the watermark:
      #
      #   :written_unconfirmed  merged and written, still awaiting confirmation
      #   :confirmed            an earlier write was proven durable and dropped
      #   :deferred             enqueued only, nothing flushed this call
      #   :failed               refused or errored, the work is the caller's again
      #   :unavailable          the backend cannot be reached at all, same
      ###
      class Base
        ABSTRACT_KEY = "abstract"

        def entries
          raise ABSTRACT_KEY
        end

        def record(_delta)
          raise ABSTRACT_KEY
        end

        def delete_entry(_key)
          raise ABSTRACT_KEY
        end

        def reset
          raise ABSTRACT_KEY
        end

        def tracking_since
          raise ABSTRACT_KEY
        end

        def generation
          raise ABSTRACT_KEY
        end

        def data_loss
          nil
        end

        def pending_size
          0
        end

        # the generation pointer holder, when this repository has one to batch
        def pointer_session
          nil
        end

        # keys another process deleted since the last read, so trackers can drop
        # them from their permanent local dedupe and record them again if used
        def newly_tombstoned
          []
        end
      end
    end
  end
end
