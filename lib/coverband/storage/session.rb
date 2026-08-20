# frozen_string_literal: true

require_relative "document"
require_relative "writer"
require_relative "generation_coordinator"
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

      # held because it cannot be written. DataLoss says something is gone; this
      # says nothing is arriving, which for a quiet document is otherwise
      # indistinguishable from an app that used nothing
      UnwrittenWork = Struct.new(:deltas, :since, keyword_init: true)

      DEFAULT_MAX_ENTRIES = 5
      DEFAULT_MAX_BYTES = 8 * 1024 * 1024
      # stays well under the pruning horizon so a delta can never outlive its
      # own guard, or the tombstone that would have filtered it
      DEFAULT_MAX_AGE = 60 * 60
      DEFAULT_PRUNE_HORIZON = 12 * 60 * 60
      KEEP_ALIVE_AFTER = 3 * 24 * 60 * 60

      attr_reader :data_loss

      ###
      # A document that can never be written -- past memcached's value limit, say
      # -- reports nothing otherwise: its caps never fire, because a quiet tracker
      # enqueues nothing new to drop, so only the age cap converts the stall into
      # a loss, an hour later by default.
      ###
      def unwritten
        return nil unless @unwritten_since
        return nil if @writer.pending_size.zero?

        UnwrittenWork.new(deltas: @writer.pending_size, since: Time.at(@unwritten_since))
      end

      def initialize(target:, key_base:, merger:, logger: nil,
        max_entries: DEFAULT_MAX_ENTRIES, max_bytes: DEFAULT_MAX_BYTES,
        max_age: DEFAULT_MAX_AGE, prune_horizon: DEFAULT_PRUNE_HORIZON,
        grace_seconds: 1200, keep_alive_after: KEEP_ALIVE_AFTER,
        on_generation_change: nil, retain_on_failure: false)
        @target = target
        @key_base = key_base
        @merger = merger
        @logger = logger
        @prune_horizon = prune_horizon
        @keep_alive_after = keep_alive_after
        @on_generation_change = on_generation_change
        @retain_on_failure = retain_on_failure
        @writer = Writer.new(max_entries: max_entries, max_bytes: max_bytes, max_age: max_age)
        @generation_coordinator = GenerationCoordinator.new(
          target: target,
          key_base: key_base,
          grace_seconds: grace_seconds,
          on_change: ->(change) { handle_generation_change(change) }
        )
        @data_loss = nil
        @last_write_at = nil
      end

      def generation_token
        safely { @generation_coordinator.token }
      end

      def pointer_key
        @generation_coordinator.pointer_key
      end

      def prime_pointer(pointer)
        @generation_coordinator.prime_pointer(pointer)
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
      # the keep-alive; enqueuing it would rewrite the document every quiet cycle.
      #
      # The generation is resolved before the payload is enqueued, and retention
      # only protects deltas that reached the queue, so anything that did not
      # get there is held for the next cycle.
      ###
      def record(payload)
        # "nothing to take" is not "taken": an empty payload leaves the caller
        # holding nothing, so a failure there still has to be raised
        nothing_to_take = payload.nil? || payload.empty?
        taken = false
        operation do
          unless nothing_to_take || taken
            enqueue(payload)
            taken = true
          end
          flush
        end
      rescue Target::Unavailable => error
        retain(payload) unless taken || nothing_to_take
        log_unavailable(error)
        taken ? :retained : :unavailable
      rescue => error
        # whether the work is ours decides who keeps it, and whether this may
        # raise at all: a caller that sees an exception keeps its copy, so raising
        # after we took the delta gives it two owners and replays it
        if taken
          note_unwritten
          log("failed to store #{@key_base}, retaining #{@writer.pending_size} pending deltas, " \
            "#{error.class}: #{error.message}")
          :retained
        else
          retain(payload) unless nothing_to_take
          raise
        end
      end

      ###
      # A fresh token retires the whole generation, so stragglers write to a key
      # nothing reads. False when the pointer write didn't land: a reset that
      # isn't durable is a failure, never a silent partial reset.
      ###
      def reset
        @generation_coordinator.reset
      rescue Target::Unavailable => error
        log_unavailable(error)
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
            @written_through = nil
          end

          prefix = @writer.contiguous_prefix(watermark)
          # pending work yielding no prefix is a sequence hole, left by a drop
          # that had no watermark to rebase against. Closing it here rather than
          # tracking who owes a rebase keeps the invariant structural
          if prefix.empty? && @writer.pending_size > 0
            @writer.rebase_pending!(watermark)
            @written_through = nil
            prefix = @writer.contiguous_prefix(watermark)
          end

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
            @written_through = prefix.last.seq
            :written_unconfirmed
          else
            # not durable, but ours: everything stays pending for the next cycle,
            # so a caller holding a second copy would replay it
            note_unwritten
            log("failed to write #{@key_base} (#{doc.to_json.bytesize} bytes), retaining " \
              "#{@writer.pending_size} pending deltas. A backend value limit (memcached's is " \
              "1MB by default) will refuse this every cycle until the limit is raised or the " \
              "store is changed")
            :retained
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
        @generation_coordinator.discard_primed_pointer!
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
      # Holds a payload that never reached the queue, stamped with the last epoch
      # observed -- zero if none, which can filter the delta against an existing
      # tombstone but never resurrect a deleted key.
      #
      # Off by default: only a caller that hands work over and forgets it can use
      # this. Coverage does; a tracker keeps its own keys, so retaining here too
      # replays them, which for the additive trackers double counts.
      #
      # The caps run here because a sustained outage never reaches flush, where
      # they normally do. Dropping leaves a sequence hole only a flush can close,
      # since only it knows the watermark to rebase against.
      ###
      # a misconfiguration can never resolve, so it is said once; "not ready yet"
      # is said each cycle, because each line is a cycle that was deferred
      def log_unavailable(error)
        return log(error.message) unless error.is_a?(Target::Misconfigured)
        return if @misconfiguration_logged

        @misconfiguration_logged = true
        @logger&.error("Coverband: #{error.message}")
      end

      def retain(payload)
        return unless @retain_on_failure
        return if payload.nil? || payload.empty?

        @writer.enqueue(payload, tombstone_epoch: @observed_tombstone_epoch.to_i)
        note_unwritten
        record_dropped(@writer.enforce_caps!)
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
          @generation_coordinator.document_evicted!
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
          @unwritten_since = nil
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
      # The coordinator classifies pointer transitions. This consumer owns only
      # the session consequences: drop incompatible work for a reset, report an
      # orphan for pointer eviction, and carry safe initialization-race work into
      # the authoritative generation.
      ###
      def handle_generation_change(change)
        case change.cause
        when GenerationChange::POINTER_EVICTION
          record_loss(:orphaned_generation,
            "pointer for #{@key_base} disappeared, generation #{change.previous_token} is orphaned")
          drop_local_state!(change)
        when GenerationChange::OPERATOR_RESET
          drop_local_state!(change)
        when GenerationChange::INITIALIZATION_RACE
          log("lost a pointer initialization race for #{@key_base}, carrying #{@writer.pending_size} deltas forward")
          @seen_document = false
          @observed_tombstone_epoch = nil
          @on_generation_change&.call(change)
        when GenerationChange::DOCUMENT_EVICTION
          @on_generation_change&.call(change)
        end
      end

      def drop_local_state!(change)
        @writer.rotate_identity!
        @written_through = nil
        @observed_tombstone_epoch = nil
        @seen_document = false
        # epochs restart at zero in a new generation, so a larger remembered one
        # would ignore the new generation's first deletes
        @tombstones_seen = nil
        @tombstone_notifications = []
        @on_generation_change&.call(change)
      end

      def operation(&block)
        @generation_coordinator.operation(&block)
      end

      def data_key
        @generation_coordinator.data_key
      end

      ###
      # Only lost if it never reached a document. One already written and merely
      # awaiting confirmation is in the payload; dropping it forfeits the repair
      # if another writer clobbered that write -- a weaker claim than "results
      # before this point are unavailable", and it has to read differently.
      ###
      def record_dropped(dropped)
        return if dropped.empty?

        if @written_through && dropped.all? { |delta| delta.seq <= @written_through }
          record_loss(:unconfirmed_dropped,
            "gave up the retry for #{dropped.length} deltas already written but never confirmed")
        else
          record_loss(:pending_dropped, "dropped #{dropped.length} deltas that outlived the retention caps")
        end
      end

      def note_unwritten
        @unwritten_since ||= Time.now.to_i
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
