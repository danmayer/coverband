# frozen_string_literal: true

require_relative "document"
require_relative "generation"
require_relative "writer"

module Coverband
  module Storage
    ###
    # Runs the merge protocol for one document.
    #
    # Conflicting writes are retried idempotently and normally converge while
    # the originating writer is alive and the delta is still pending. That is
    # the whole guarantee: conflict is repaired, not prevented.
    #
    # Every whole document read modify write layout uses applied sequences for
    # conflict detection. Non-idempotent layouts additionally depend on them for
    # retry safety, since re-applying a sum would double count.
    ###
    class Session
      DataLoss = Struct.new(:at, :kind, :detail, keyword_init: true)

      DEFAULT_MAX_ENTRIES = 5
      DEFAULT_MAX_BYTES = 8 * 1024 * 1024
      # stays well under the pruning horizon so a delta can never outlive its
      # own guard, or the tombstone that would have filtered it
      DEFAULT_MAX_AGE = 60 * 60
      DEFAULT_PRUNE_HORIZON = 12 * 60 * 60
      KEEP_ALIVE_AFTER = 3 * 24 * 60 * 60

      attr_reader :data_loss

      def initialize(target:, key_base:, merger:, logger: nil,
        max_entries: DEFAULT_MAX_ENTRIES, max_bytes: DEFAULT_MAX_BYTES,
        max_age: DEFAULT_MAX_AGE, prune_horizon: DEFAULT_PRUNE_HORIZON,
        grace_seconds: 1200, keep_alive_after: KEEP_ALIVE_AFTER,
        on_generation_change: nil)
        @target = target
        @key_base = key_base
        @merger = merger
        @logger = logger
        @prune_horizon = prune_horizon
        @keep_alive_after = keep_alive_after
        @on_generation_change = on_generation_change
        @writer = Writer.new(max_entries: max_entries, max_bytes: max_bytes, max_age: max_age)
        @generation = Generation.new(target, "#{key_base}.pointer", grace_seconds: grace_seconds)
        @token = nil
        @initialized_token = false
        @data_loss = nil
        @last_write_at = nil
      end

      def generation_token
        operation { @token }
      end

      def entries
        operation { document.payload }
      end

      def tracking_since
        operation do
          started = document.started_at
          started ? Time.at(started) : nil
        end
      end

      def pending_size
        @writer.pending_size
      end

      def enqueue(payload)
        operation { @writer.enqueue(payload, tombstone_epoch: observed_tombstone_epoch) }
      end

      def enqueue_delete(key)
        operation do
          @writer.enqueue({}, tombstone_epoch: observed_tombstone_epoch, kind: :delete, key: key.to_s)
        end
      end

      def record(payload)
        operation do
          enqueue(payload)
          flush
        end
      end

      ###
      # A fresh token retires the whole generation, so stragglers write to a key
      # nothing reads. Returns false when the pointer write didn't land: a reset
      # that isn't durable must be reported as a failure, never as a silent
      # partial reset.
      ###
      def reset
        operation do
          token = @generation.reset!(current_token: @token)
          next false unless token

          @token = token
          @initialized_token = false
          drop_local_state!
          true
        end
      end

      def delete_entry(key)
        operation do
          enqueue_delete(key)
          flush
        end
      end

      ###
      # The six step write algorithm.
      ###
      def flush
        operation do
          doc = document
          watermark = resolve_watermark(doc)

          confirmed = @writer.confirm_through(watermark)
          record_dropped(@writer.enforce_caps!)

          prefix = @writer.contiguous_prefix(watermark)
          if prefix.empty?
            keep_alive(doc)
            next((confirmed > 0) ? :confirmed : :deferred)
          end

          apply(doc, prefix)
          doc.record_watermark(@writer.writer_id, prefix.last.seq, host: @writer.host, pid: @writer.pid)
          doc.started_at!
          doc.prune!(horizon: @prune_horizon)

          if write(doc)
            :written_unconfirmed
          else
            # not durable: keep everything pending so the next cycle retries
            log("failed to write #{@key_base}, retaining #{@writer.pending_size} pending deltas")
            :failed
          end
        end
      end

      def clear_local_data_loss!
        @data_loss = nil
      end

      ###
      # Forfeits unconfirmed deltas. They are held so a conflicting write can be
      # repaired on the next cycle, so dropping them trades that repair for the
      # memory. Only for benchmarks and shutdown paths, never during normal
      # reporting.
      ###
      def discard_pending!
        @writer.clear_pending!
      end

      ###
      # Keys another process deleted since we last looked. Presence trackers
      # keep keys in a permanent local dedupe set, so without this a cleared key
      # would never be enqueued again no matter how often it is used.
      #
      # Drained from what the last document read already told us, so asking
      # costs nothing.
      ###
      def newly_tombstoned
        drained = @tombstone_notifications || []
        @tombstone_notifications = []
        drained
      end

      private

      def apply(doc, prefix)
        prefix.each do |delta|
          if delta.kind == :delete
            doc.add_tombstone(delta.key)
          else
            @merger.call(doc, delta)
          end
        end
      end

      def resolve_watermark(doc)
        watermark = doc.watermark_for(@writer.writer_id)

        ###
        # A writer that has seen its own watermark and then finds it gone can't
        # tell whether its deltas are in the payload. Re-applying could double
        # count, assuming durability could lose data, so it becomes someone else
        # and gives up the ambiguous deltas.
        ###
        if !doc.watermark_present?(@writer.writer_id) && @writer.observed_watermark? && @writer.pending_size > 0
          abandoned = @writer.rotate_identity!
          record_loss(:identity_rotated, "abandoned #{abandoned.length} deltas with an ambiguous watermark")
          return 0
        end

        @writer.observed_watermark!(watermark)
        watermark
      end

      ###
      # One pointer read per public call, not one per internal helper. The
      # pointer is small, but a report cycle shouldn't pay for it repeatedly.
      ###
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
          # the parsed pointer is only needed for the sweep above, and holding
          # it would retain a copy of the pointer document between reports
          @pointer = nil
        end
      end

      def document
        raw = @target.read(data_key)
        doc = Document.parse(raw)

        if doc.nil?
          record_loss(:corrupt_document, "unparseable document at #{data_key}")
          doc = Document.new
        elsif raw.nil? && @seen_document
          record_loss(:eviction, "document #{data_key} disappeared")
          @seen_document = false
        end

        @seen_document = true unless raw.nil?
        note_tombstones(doc)
        doc
      end

      def note_tombstones(doc)
        seen = @tombstones_seen || 0
        return if doc.tombstone_epoch <= seen

        fresh = doc.tombstones.select { |_key, epoch| epoch.to_i > seen }.keys
        @tombstone_notifications = (@tombstone_notifications || []) | fresh
        @tombstones_seen = doc.tombstone_epoch
      end

      def observed_tombstone_epoch
        @observed_tombstone_epoch ||= document.tombstone_epoch
      end

      def write(doc)
        @observed_tombstone_epoch = doc.tombstone_epoch
        result = @target.write(data_key, doc.to_json)
        @last_write_at = Time.now.to_i if result
        result
      end

      ###
      # Coverband writes deltas, not heartbeats, so a document that stops seeing
      # new keys stops being written and ages out of a cache that expires by
      # write age. Touching a document is safe (it is an ordinary empty delta
      # write the protocol already repairs); touching the pointer is not.
      ###
      def keep_alive(doc)
        return unless @keep_alive_after
        return if doc.empty?

        last = @last_write_at || doc.started_at
        return unless last
        return if (Time.now.to_i - last) < jittered_keep_alive

        doc.record_watermark(@writer.writer_id, doc.watermark_for(@writer.writer_id),
          host: @writer.host, pid: @writer.pid)
        write(doc)
      end

      def jittered_keep_alive
        @jittered_keep_alive ||= @keep_alive_after + rand(@keep_alive_after / 4)
      end

      def sync_generation
        return if @synced

        @synced = true
        result = @generation.resolve
        @sweep_due = !Array(result.pointer && result.pointer[Generation::RETIRE]).empty?
        @pointer = result.pointer if @sweep_due

        if @token.nil?
          @token = result.token
          @initialized_token = result.initialized
          return
        end

        return if result.token == @token

        ###
        # Two very different reasons the token can change, and they want
        # opposite handling. An operator reset means drop everything. Losing an
        # initialization race means our unconfirmed deltas were written to a
        # generation that can never become authoritative again, so carrying them
        # forward can't double count.
        ###
        if @initialized_token
          log("lost a pointer initialization race for #{@key_base}, carrying #{@writer.pending_size} deltas forward")
        else
          drop_local_state!
        end

        @token = result.token
        @initialized_token = false
        @seen_document = false
        @observed_tombstone_epoch = nil
      end

      def drop_local_state!
        @writer.rotate_identity!
        @observed_tombstone_epoch = nil
        @seen_document = false
        @on_generation_change&.call
      end

      def data_key
        "#{@key_base}.g#{@token}"
      end

      def record_dropped(dropped)
        return if dropped.empty?

        record_loss(:pending_dropped, "dropped #{dropped.length} deltas that outlived the retention caps")
      end

      def record_loss(kind, detail)
        @data_loss = DataLoss.new(at: Time.now, kind: kind, detail: detail)
        log("data loss (#{kind}) for #{@key_base}: #{detail}")
      end

      def log(message)
        @logger&.info("Coverband: #{message}")
      end
    end
  end
end
