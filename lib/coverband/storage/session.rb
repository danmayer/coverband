# frozen_string_literal: true

require_relative "document"
require_relative "generation"
require_relative "writer"
require_relative "generation_lifecycle"
require_relative "read_fallback"

module Coverband
  module Storage
    ###
    # Runs the merge protocol for one document.
    #
    # Conflict is repaired, not prevented: a clobbered write converges while the
    # originating writer is alive and its delta is still pending. Applied
    # sequences are what detect the conflict, and for non-idempotent merges they
    # are also what makes the retry safe, since re-applying a sum would double
    # count.
    ###
    class Session
      include GenerationLifecycle
      include ReadFallback

      # every pointer a reporting cycle needs, in one round trip instead of one
      # small read per document
      def self.prefetch_pointers(target, sessions)
        sessions = Array(sessions).compact.select { |session| session.respond_to?(:pointer_key) }
        return if sessions.length < 2
        return unless target.respond_to?(:read_multi)

        found = target.read_multi(*sessions.map(&:pointer_key))
        sessions.each do |session|
          raw = found[session.pointer_key]
          next if raw.nil?

          # parsed here so the batch's raw strings are not held after it returns
          parsed = begin
            raw.is_a?(Hash) ? raw : JSON.parse(raw)
          rescue JSON::ParserError
            nil
          end
          session.prime_pointer(parsed) if parsed
        end
      rescue => error
        # an optimization only: on failure each session reads its own pointer
        Coverband.configuration.logger&.debug("Coverband: pointer prefetch failed #{error.class}")
      end

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
        safely { generation }
      end

      def entries
        safely({}) { operation { document.payload } }
      end

      def tracking_since
        safely do
          operation do
            started = document.started_at
            started ? Time.at(started) : nil
          end
        end
      end

      def pending_size
        @writer.pending_size
      end

      ###
      # Bytes stored, or nil for nothing stored. Goes through operation because a
      # freshly built session has no token yet, and reading its key directly
      # would address ".g" and report nothing for coverage that is really there.
      ###
      def stored_size
        safely {
          operation {
            raw = @target.read(data_key)
            raw&.to_s&.bytesize
          }
        }
      end

      def enqueue(payload)
        operation { @writer.enqueue(payload, tombstone_epoch: observed_tombstone_epoch) }
      end

      def enqueue_delete(key)
        operation do
          @writer.enqueue({}, tombstone_epoch: observed_tombstone_epoch, kind: :delete, key: key.to_s)
        end
      end

      ###
      # An empty payload still needs the flush, to confirm earlier work and run
      # the keep-alive; enqueuing it would rewrite the document every quiet
      # cycle.
      #
      # Generation resolution happens before the payload is enqueued, so a
      # backend that fails there would drop the cycle's work entirely: the
      # retention protocol only protects deltas that reached the queue. Anything
      # that did not get enqueued is held for the next cycle.
      ###
      def record(payload)
        enqueued = payload.nil? || payload.empty?
        operation do
          unless enqueued
            enqueue(payload)
            enqueued = true
          end
          flush
        end
      rescue Target::Unavailable => error
        retain(payload) unless enqueued
        log(error.message)
        :deferred
      rescue
        retain(payload) unless enqueued
        raise
      end

      ###
      # A fresh token retires the whole generation, so stragglers write to a key
      # nothing reads. False when the pointer write didn't land: a reset that
      # isn't durable is a failure, never a silent partial reset.
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
      rescue Target::Unavailable => error
        log(error.message)
        false
      end

      def delete_entry(key)
        operation do
          enqueue_delete(key)
          flush
        end
      end

      def flush
        operation do
          doc = document
          watermark = resolve_watermark(doc)

          confirmed = @writer.confirm_through(watermark)

          dropped = @writer.enforce_caps!
          if dropped.any?
            record_dropped(dropped)
            # the dropped work is gone for good, so step over the hole it left
            # rather than stalling on it forever
            @writer.rebase_pending!(watermark)
          end

          prefix = @writer.contiguous_prefix(watermark)
          if prefix.empty?
            if @data_loss && !@data_loss_persisted
              persist_data_loss(doc)
              write(doc) # a refused write stays unpersisted and retries next cycle
            end
            keep_alive(doc)
            next((confirmed > 0) ? :confirmed : :deferred)
          end

          persist_data_loss(doc)
          apply(doc, prefix)
          doc.record_watermark(@writer.writer_id, prefix.last.seq, host: @writer.host, pid: @writer.pid)
          doc.started_at!
          doc.prune!(horizon: @prune_horizon)

          if write(doc)
            :written_unconfirmed
          else
            # not durable: everything stays pending for the next cycle
            log("failed to write #{@key_base}, retaining #{@writer.pending_size} pending deltas")
            :failed
          end
        end
      end

      def clear_local_data_loss!
        @data_loss = nil
      end

      ###
      # Drops the state a reporting cycle accumulates: unconfirmed deltas, and
      # any pointer primed by the cycle's batched read. Both are bounded and
      # deliberate, but they are held between cycles, so a leak check has to be
      # able to put the session back to a quiet baseline. Forfeits the repair
      # those deltas would have done, so it is for benchmarks and shutdown only.
      ###
      def discard_pending!
        @writer.clear_pending!
        clear_primed_pointer!
      end

      ###
      # Keys another process deleted since we last looked, drained from what the
      # last read already told us. Presence trackers dedupe locally and forever,
      # so without this a cleared key is never enqueued again however often it
      # is used.
      ###
      def newly_tombstoned
        drained = @tombstone_notifications || []
        @tombstone_notifications = []
        drained
      end

      private

      ###
      # Holds a payload that never reached the queue, stamped with the last
      # epoch this session observed -- the same stamp the next cycle would use.
      # Zero when nothing has been observed yet, which can only filter the delta
      # against an existing tombstone, never resurrect a deleted key.
      ###
      def retain(payload)
        return if payload.nil? || payload.empty?

        @writer.enqueue(payload, tombstone_epoch: @observed_tombstone_epoch.to_i)
      rescue => error
        log("could not retain work for #{@key_base}, #{error.class}: #{error.message}")
      end

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

        # having seen its own watermark and then found it gone, a writer cannot
        # tell whether its deltas are in the payload; re-applying could double
        # count and assuming durability could lose data, so it becomes someone
        # else and gives up the ambiguous deltas
        if !doc.watermark_present?(@writer.writer_id) && @writer.observed_watermark? && @writer.pending_size > 0
          abandoned = @writer.rotate_identity!
          record_loss(:identity_rotated, "abandoned #{abandoned.length} deltas with an ambiguous watermark")
          return 0
        end

        @writer.observed_watermark!(watermark)
        watermark
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
          # trackers dedupe locally and forever, so the keys they could still
          # re-report would stay unreported after an eviction
          @on_generation_change&.call(:eviction)
        end

        @seen_document = true unless raw.nil?
        # our own marker, read back from storage: now it is durable
        if @data_loss && doc.data_loss_at && doc.data_loss_at >= @data_loss.at.to_i
          @data_loss_persisted = true
        end

        # a loss another process recorded is still a loss for this report
        if @data_loss.nil? && doc.data_loss_at
          @data_loss = DataLoss.new(at: Time.at(doc.data_loss_at),
            kind: (doc.data_loss_kind || "eviction").to_sym,
            detail: "recorded by another process")
        end
        @observed_tombstone_epoch = doc.tombstone_epoch
        note_tombstones(doc)
        doc
      end

      def note_tombstones(doc)
        seen = @tombstones_seen || 0
        return if doc.tombstone_epoch <= seen

        fresh = doc.tombstone_keys_above(seen)
        @tombstone_notifications = (@tombstone_notifications || []) | fresh
        @tombstones_seen = doc.tombstone_epoch
      end

      # has to track what we have actually seen: a writer holding a stale 0 would
      # stamp genuine new observations as pre-delete and have them filtered out
      def observed_tombstone_epoch
        @observed_tombstone_epoch || document.tombstone_epoch
      end

      def write(doc)
        @observed_tombstone_epoch = doc.tombstone_epoch
        result = @target.write(data_key, doc.to_json)
        if result
          @last_write_at = Time.now.to_i
          # it exists now, so a later absence is the backend dropping it rather
          # than us never having written
          @seen_document = true
        end
        result
      end

      ###
      # Coverband writes deltas, not heartbeats, so a document that stops seeing
      # new keys stops being written and ages out of a cache that expires by
      # write age. Touching the document is safe -- an ordinary write the
      # protocol already repairs. Touching the pointer is not.
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

      ###
      # Two reasons the token can change, wanting opposite handling. An operator
      # reset means drop everything. A lost initialization race means our deltas
      # went to a generation that can never become authoritative, so carrying
      # them forward cannot double count.
      #
      # Telling them apart takes evidence, not a flag: a reset names the token it
      # retired, and a backend with atomic create cannot produce a race at all.
      # Anything unproven is treated as a reset, since carrying work across a
      # deliberate clear is the worse mistake.
      ###
      def on_generation_changed(result)
        # the pointer vanished while we were using it, so whatever it addressed
        # may still be in the backend, unreachable: that is loss worth reporting
        if result.pointer_missing
          record_loss(:orphaned_generation, "pointer for #{@key_base} disappeared, generation #{@token} is orphaned")
          @token = result.token
          drop_local_state!(:eviction)
          return
        end

        if lost_initialization_race?(result.pointer)
          log("lost a pointer initialization race for #{@key_base}, carrying #{@writer.pending_size} deltas forward")
        else
          drop_local_state!
        end

        @initialized_token = false
        @seen_document = false
        @observed_tombstone_epoch = nil
      end

      def on_generation_initialized(result)
        @initialized_token = result.initialized
      end

      # reading our own token back settles the initialization race, so a later
      # change is a reset rather than a lost race
      def on_generation_confirmed(_result)
        @initialized_token = false
      end

      def lost_initialization_race?(pointer)
        return false unless @initialized_token
        return false if atomic_create_target?
        return false if @generation.retires?(pointer, @token)

        true
      end

      def atomic_create_target?
        @target.respond_to?(:atomic_create?) && @target.atomic_create?
      end

      def drop_local_state!(reason = :reset)
        @writer.rotate_identity!
        @observed_tombstone_epoch = nil
        @seen_document = false
        # epochs restart at zero in a new generation, so a larger remembered one
        # would ignore the new generation's first deletes
        @tombstones_seen = nil
        @tombstone_notifications = []
        @on_generation_change&.call(reason)
      end

      def record_dropped(dropped)
        return if dropped.empty?

        record_loss(:pending_dropped, "dropped #{dropped.length} deltas that outlived the retention caps")
      end

      def record_loss(kind, detail)
        @data_loss = DataLoss.new(at: Time.now, kind: kind, detail: detail)
        @data_loss_persisted = false
        log("data loss (#{kind}) for #{@key_base}: #{detail}")
      end

      ###
      # Stamps the loss onto the document about to be written, without marking it
      # persisted: the write can be refused or clobbered, and believing it landed
      # would drop the marker for good. Confirmation comes from reading it back.
      ###
      def persist_data_loss(doc)
        return if @data_loss.nil? || @data_loss_persisted

        doc.data_loss_at = @data_loss.at
        doc.data_loss_kind = @data_loss.kind
      end
    end
  end
end
