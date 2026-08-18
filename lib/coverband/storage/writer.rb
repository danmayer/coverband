# frozen_string_literal: true

require "securerandom"
require "socket"

module Coverband
  module Storage
    ###
    # Identity of one reporting process, plus its queue of unconfirmed deltas.
    #
    # Identity is a process lifetime nonce, never a hash of hostname and pid:
    # pids get reused, and a restarted process inheriting a dead writer's high
    # watermark would see its own new low sequences treated as already applied.
    # host and pid ride along for humans reading the stored document.
    ###
    class Writer
      Delta = Struct.new(:seq, :payload, :tombstone_epoch, :enqueued_at, :kind, :key, keyword_init: true)

      attr_reader :max_entries, :max_bytes, :max_age

      def initialize(max_entries:, max_bytes:, max_age:)
        @max_entries = max_entries
        @max_bytes = max_bytes
        @max_age = max_age
        reset_identity!
      end

      def writer_id
        check_fork!
        @writer_id
      end

      def pending
        check_fork!
        @pending
      end

      def host
        @host ||= begin
          Socket.gethostname
        rescue
          "unknown"
        end
      end

      attr_reader :pid

      ###
      # Deltas are frozen at enqueue. Re-expanding one on retry would hand it a
      # fresh timestamp, letting it slip past a tombstone recorded in between.
      ###
      def enqueue(payload, tombstone_epoch:, kind: :merge, key: nil)
        check_fork!
        @seq += 1
        delta = Delta.new(
          seq: @seq,
          payload: payload.freeze,
          tombstone_epoch: tombstone_epoch,
          enqueued_at: Time.now.to_i,
          kind: kind,
          key: key
        ).freeze
        @pending << delta
        delta
      end

      ###
      # Everything through the watermark is proven durable, so it can go.
      def confirm_through(seq)
        check_fork!
        confirmed = @pending.count { |delta| delta.seq <= seq }
        @pending.reject! { |delta| delta.seq <= seq }
        confirmed
      end

      ###
      # The contiguous prefix above the watermark. Stopping at the first gap is
      # what makes the watermark an invariant rather than a hint: we can never
      # record seq 2 onto a document that is missing seq 1.
      ###
      def contiguous_prefix(watermark)
        check_fork!
        expected = watermark + 1
        prefix = []
        @pending.sort_by(&:seq).each do |delta|
          break if delta.seq != expected

          prefix << delta
          expected += 1
        end
        prefix
      end

      ###
      # Drops whatever has outlived its guard. Returns the dropped deltas so the
      # caller can record data loss; silently discarding them is what we are
      # trying to avoid.
      ###
      def enforce_caps!
        check_fork!
        dropped = []
        now = Time.now.to_i

        @pending.reject! do |delta|
          aged_out = (now - delta.enqueued_at) > @max_age
          dropped << delta if aged_out
          aged_out
        end

        while @pending.length > @max_entries
          dropped << @pending.shift
        end

        while @pending.length > 1 && pending_bytes > @max_bytes
          dropped << @pending.shift
        end

        dropped
      end

      def pending_bytes
        @pending.sum { |delta| delta.payload.to_s.bytesize }
      end

      def pending_size
        @pending.length
      end

      ###
      # Renumbers surviving deltas so they sit contiguously above the watermark.
      #
      # Dropping a delta at the retention caps otherwise leaves a hole the
      # prefix can never step over: contiguous_prefix looks for watermark + 1,
      # finds the dropped sequence missing, and returns nothing on this flush
      # and every flush after it. The document would silently stop being written.
      #
      # Payloads, enqueue times, and observed tombstone epochs are carried
      # across untouched, since a delta must stay immutable once enqueued.
      ###
      def rebase_pending!(watermark)
        # even with nothing left, the counter has to come back to the watermark,
        # or the next enqueue starts above it and every prefix stays empty
        if @pending.empty?
          @seq = watermark
          return
        end

        next_seq = watermark + 1
        @pending = @pending.sort_by(&:seq).map do |delta|
          rebased = Delta.new(
            seq: next_seq,
            payload: delta.payload,
            tombstone_epoch: delta.tombstone_epoch,
            enqueued_at: delta.enqueued_at,
            kind: delta.kind,
            key: delta.key
          ).freeze
          next_seq += 1
          rebased
        end
        @seq = next_seq - 1
      end

      def clear_pending!
        @pending.clear
      end

      ###
      # A writer that has seen its own watermark and then finds it gone cannot
      # tell "pruned but applied" from "never applied". Neither guess is safe,
      # so it becomes a different writer and gives up its ambiguous deltas.
      ###
      def rotate_identity!
        abandoned = @pending.dup
        reset_identity!
        abandoned
      end

      def observed_watermark!(seq)
        @observed_watermark = true if seq > 0
      end

      def observed_watermark?
        @observed_watermark
      end

      ###
      # Forked children must not re-apply deltas the parent may already have
      # applied, and must not share the parent's sequence counter.
      ###
      def check_fork!
        return if @pid == Process.pid

        reset_identity!
      end

      private

      def reset_identity!
        @writer_id = SecureRandom.hex(8)
        @seq = 0
        @pending = []
        @observed_watermark = false
        @pid = Process.pid
      end
    end
  end
end
