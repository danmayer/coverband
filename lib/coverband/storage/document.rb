# frozen_string_literal: true

require "json"

module Coverband
  module Storage
    ###
    # One stored unit: metadata and payload, written together and reverted
    # together.
    #
    # The co-reversion half matters as much as the co-writing half. A layout
    # where a stale write can revert the metadata while leaving payload
    # contributions intact (a Redis hash with metadata in a reserved field)
    # silently breaks the watermark, so non-idempotent merges must live in a
    # document like this one.
    ###
    class Document
      META = "meta"
      PAYLOAD = "payload"
      APPLIED = "applied"
      STARTED_AT = "started_at"
      TOMBSTONE_EPOCH = "tombstone_epoch"
      TOMBSTONES = "tombstones"
      DATA_LOSS_AT = "data_loss_detected_at"
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
      # first. No wall clock is involved anywhere, so clock skew and same second
      # granularity can't resurrect a deleted key.
      ###
      def tombstoned?(key, observed_epoch)
        epoch = tombstones[key.to_s]
        return false unless epoch

        observed_epoch.to_i < epoch.to_i
      end

      def add_tombstone(key)
        @meta[TOMBSTONE_EPOCH] = tombstone_epoch + 1
        tombstones[key.to_s] = tombstone_epoch
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

      ###
      # Pruning has to stay outside the pending age cap, or a delayed delta
      # could outlive the guard that keeps it from being applied twice.
      ###
      def prune!(horizon:)
        now = Time.now.to_i
        applied.delete_if { |_id, entry| (now - entry[LAST_SEEN].to_i) > horizon }
        return if tombstone_epoch.zero?

        # tombstones are only needed while a delta old enough to need filtering
        # could still exist, which the age cap bounds
        tombstones.delete_if { |_key, epoch| (tombstone_epoch - epoch.to_i) > TOMBSTONE_RETAIN }
      end

      TOMBSTONE_RETAIN = 1000

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
