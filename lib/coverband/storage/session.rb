# frozen_string_literal: true

require_relative "document"
require_relative "generation"
require_relative "writer"
require_relative "generation_lifecycle"

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
      include GenerationLifecycle

      ###
      # Reads every pointer a reporting cycle is about to need in one round
      # trip. Each document otherwise pays for its own small pointer read.
      ###
      def self.prefetch_pointers(target, sessions)
        sessions = Array(sessions).compact.select { |session| session.respond_to?(:pointer_key) }
        return if sessions.length < 2
        return unless target.respond_to?(:read_multi)

        found = target.read_multi(*sessions.map(&:pointer_key))
        sessions.each { |session| session.prime_pointer(found[session.pointer_key]) }
      rescue => error
        # batching is an optimization; a failure here just means each session
        # reads its own pointer as before
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
      # Bytes of the stored document, or nil when there is nothing stored.
      #
      # Goes through the normal operation lifecycle: a freshly built session has
      # no token yet, so reading its key directly would address ".g" and report
      # nothing for coverage that is really there.
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
      # An empty payload still needs a flush, to confirm earlier work and let
      # the keep-alive run, but enqueuing it would advance the watermark and
      # rewrite the whole document every quiet cycle.
      ###
      def record(payload)
        operation do
          enqueue(payload) unless payload.nil? || payload.empty?
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
              # a refused write leaves it unpersisted, so the next cycle retries
              write(doc)
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
      ###
      # Drops the transient state a reporting cycle accumulates: unconfirmed
      # deltas, and any pointer primed by the cycle's batched read. Both are
      # bounded and deliberate, but they are held between cycles, so a leak
      # check has to be able to put the session back to a quiet baseline.
      ###
      def discard_pending!
        @writer.clear_pending!
        clear_primed_pointer!
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

      def document
        raw = @target.read(data_key)
        doc = Document.parse(raw)

        if doc.nil?
          record_loss(:corrupt_document, "unparseable document at #{data_key}")
          doc = Document.new
        elsif raw.nil? && @seen_document
          record_loss(:eviction, "document #{data_key} disappeared")
          @seen_document = false
          ###
          # Trackers dedupe locally and forever, so without this the keys they
          # could still re-report would stay unreported after an eviction.
          ###
          @on_generation_change&.call(:eviction)
        end

        @seen_document = true unless raw.nil?
        # a loss another process recorded is still a loss for this report
        # our own marker read back from storage: now it is durable
        if @data_loss && doc.data_loss_at && doc.data_loss_at >= @data_loss.at.to_i
          @data_loss_persisted = true
        end

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

      ###
      # The epoch a delta is stamped with when it is enqueued. It has to track
      # what we have actually seen: a writer holding a stale 0 here would stamp
      # genuine new observations as pre-delete and have them filtered out.
      ###
      def observed_tombstone_epoch
        @observed_tombstone_epoch || document.tombstone_epoch
      end

      def write(doc)
        @observed_tombstone_epoch = doc.tombstone_epoch
        result = @target.write(data_key, doc.to_json)
        if result
          @last_write_at = Time.now.to_i
          # we know the document exists now, so a later absence is the backend
          # dropping it rather than us never having written
          @seen_document = true
        end
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

      ###
      # Two very different reasons the token can change, and they want opposite
      # handling. An operator reset means drop everything. Losing an
      # initialization race means our unconfirmed deltas went to a generation
      # that can never become authoritative again, so carrying them forward
      # cannot double count.
      #
      # Telling them apart needs evidence, not a flag: a reset names the token
      # it retired, and a backend with atomic create cannot produce an
      # initialization race in the first place. Anything we cannot prove was a
      # race is treated as a reset, since carrying work across a deliberate
      # clear is the worse mistake.
      ###
      def on_generation_changed(result)
        ###
        # The pointer vanished while we were using it. Whatever it addressed may
        # still be sitting in the backend, unreachable, so the loss is reported
        # rather than passed off as an ordinary generation change.
        ###
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

      ###
      # Reading our own token back as authoritative settles the initialization
      # race, so a later change is a reset rather than a lost race.
      ###
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
        # epochs restart at zero in a new generation, so remembering a larger
        # one from the retired generation would ignore its first deletes
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
      # Stamps the loss onto the document about to be written. It is not marked
      # persisted here: the write can be refused or clobbered by a stale writer,
      # and believing it landed would drop the marker for good. Confirmation
      # comes from reading it back.
      ###
      def persist_data_loss(doc)
        return if @data_loss.nil? || @data_loss_persisted

        doc.data_loss_at = @data_loss.at
        doc.data_loss_kind = @data_loss.kind
      end

      def log(message)
        @logger&.info("Coverband: #{message}")
      end

      ###
      # A backend that is down, or a Solid Cache table that has not been created
      # yet, must never raise into the request serving the report. Pending work
      # is untouched, so the next cycle retries.
      ###
      ###
      # Every way into storage runs through here. A backend that is down, or a
      # Solid Cache table that has not been created yet, has to log and return
      # the caller's fallback rather than raise into the request rendering the
      # report.
      #
      # Reads only. Write failures keep propagating to the reporting paths that
      # already rescue and log them, so their messages do not disappear.
      ###
      def safely(fallback = nil)
        yield
      rescue => error
        log_unavailable(error)
        fallback
      end

      def log_unavailable(error)
        log("storage unavailable for #{@key_base}, #{error.class}: #{error.message}")
      end
    end
  end
end
