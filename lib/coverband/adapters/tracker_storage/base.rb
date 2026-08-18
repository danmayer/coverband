# frozen_string_literal: true

module Coverband
  module Adapters
    module TrackerStorage
      ###
      # What a tracker sees. Physical keys, generations, serialization, and the
      # applied sequence protocol all live below this line; trackers deal in
      # keys and timestamps.
      #
      # record's return values name protocol states rather than outcomes,
      # because "written" and "proven durable" are different things and the
      # difference is the entire point of the watermark:
      #
      #   :written_unconfirmed  merged and written, still awaiting confirmation
      #   :confirmed            an earlier write was proven durable and dropped
      #   :deferred             enqueued only, nothing flushed this call
      #   :failed               refused or errored, pending retained for retry
      ###
      class Base
        ABSTRACT = "abstract"

        def entries
          raise ABSTRACT
        end

        def record(_delta)
          raise ABSTRACT
        end

        def delete_entry(_key)
          raise ABSTRACT
        end

        def reset
          raise ABSTRACT
        end

        def tracking_since
          raise ABSTRACT
        end

        def data_loss
          nil
        end

        def generation
          raise ABSTRACT
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

        # whether this repository keeps unconfirmed deltas itself
        def retains_pending?
          false
        end
      end
    end
  end
end
