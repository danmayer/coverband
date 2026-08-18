# frozen_string_literal: true

require "json"

module Coverband
  module Storage
    ###
    # One stored unit: metadata and payload, written together and reverted
    # together.
    #
    # Co-reversion matters as much as co-writing. A layout where a stale write
    # reverts the metadata while leaving payload contributions intact (a Redis
    # hash with metadata in a reserved field) silently breaks the watermark, so
    # non-idempotent merges have to live in a document like this one.
    ###
    class Document
      META = "meta"
      PAYLOAD = "payload"
      APPLIED = "applied"
      STARTED_AT = "started_at"
      TOMBSTONE_EPOCH = "tombstone_epoch"
      TOMBSTONES = "tombstones"
      EPOCH = "epoch"
      AT = "at"
      DATA_LOSS_AT = "data_loss_detected_at"
      DATA_LOSS_KIND = "data_loss_kind"
      SEQ = "seq"
      LAST_SEEN = "last_seen"

      attr_reader :meta, :payload

      def self.parse(raw)
        return new if raw.nil?

        parsed = raw.is_a?(String) ? JSON.parse(raw) : raw
        return new unless parsed.is_a?(Hash) && parsed.key?(META)

        new(meta: parsed[META] || {}, payload: parsed[PAYLOAD] || {})
      rescue JSON::ParserError
        # corrupt beyond use; treat as empty and let the caller flag data loss
        nil
      end

      def initialize(meta: nil, payload: {})
        @meta = default_meta.merge(meta || {})
        @payload = payload || {}
      end

      def watermark_for(writer_id)
        entry = applied[writer_id]
        entry ? entry[SEQ].to_i : 0
      end

      def watermark_present?(writer_id)
        applied.key?(writer_id)
      end

      def record_watermark(writer_id, seq, host: nil, pid: nil)
        applied[writer_id] = {
          SEQ => seq,
          LAST_SEEN => Time.now.to_i,
          "host" => host,
          "pid" => pid
        }
      end

      def applied
        @meta[APPLIED] ||= {}
      end

      def tombstone_epoch
        @meta[TOMBSTONE_EPOCH].to_i
      end

      def tombstones
        @meta[TOMBSTONES] ||= {}
      end

      ###
      # A key can only be recreated by a writer that observed the tombstone
      # first. Compared on epochs, never wall clocks, so clock skew and
      # same-second granularity can't resurrect a deleted key; the recorded time
      # is for pruning only.
      ###
      def tombstoned?(key, observed_epoch)
        epoch = tombstone_epoch_for(key)
        return false unless epoch

        observed_epoch.to_i < epoch
      end

      def tombstone_epoch_for(key)
        entry = tombstones[key.to_s]
        return nil unless entry

        entry.is_a?(Hash) ? entry[EPOCH].to_i : entry.to_i
      end

      def tombstone_keys_above(epoch)
        tombstones.select { |key, _entry| tombstone_epoch_for(key).to_i > epoch.to_i }.keys
      end

      def add_tombstone(key)
        @meta[TOMBSTONE_EPOCH] = tombstone_epoch + 1
        tombstones[key.to_s] = {EPOCH => tombstone_epoch, AT => Time.now.to_i}
        @payload.delete(key.to_s)
        tombstone_epoch
      end

      def started_at
        @meta[STARTED_AT]&.to_i
      end

      def started_at!
        @meta[STARTED_AT] ||= Time.now.to_i
      end

      def data_loss_at
        @meta[DATA_LOSS_AT]&.to_i
      end

      def data_loss_at=(time)
        @meta[DATA_LOSS_AT] = time.to_i
      end

      # travels with the timestamp; without it every loss another process reads
      # back looks like an eviction, whatever actually happened

      def data_loss_kind
        @meta[DATA_LOSS_KIND]
      end

      def data_loss_kind=(kind)
        @meta[DATA_LOSS_KIND] = kind.to_s
      end

      # stays outside the pending age cap, or a delayed delta could outlive the
      # guard that keeps it from being applied twice

      def prune!(horizon:)
        now = Time.now.to_i
        applied.delete_if { |_id, entry| (now - entry[LAST_SEEN].to_i) > horizon }
        return if tombstone_epoch.zero?

        # elapsed time, not a count of later deletes: pruning after N deletes let
        # a burst of clears drop a seconds-old tombstone while a delta stamped
        # before it was still pending and able to resurrect the key
        tombstones.delete_if do |_key, entry|
          at = entry.is_a?(Hash) ? entry[AT].to_i : 0
          # entries without a recorded time predate this format; treat them as
          # current rather than dropping the protection they provide
          at > 0 && (now - at) > horizon
        end
      end

      def to_json(*args)
        {META => @meta, PAYLOAD => @payload}.to_json(*args)
      end

      def empty?
        @payload.empty?
      end

      private

      def default_meta
        {
          APPLIED => {},
          TOMBSTONE_EPOCH => 0,
          TOMBSTONES => {}
        }
      end
    end
  end
end
