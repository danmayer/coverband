# frozen_string_literal: true

require "set"
require "singleton"

module Coverband
  module Collectors
    ###
    # This abstract class makes it easy to track any used/unused with timestamp set of usage
    ###
    class AbstractTracker
      REPORT_ROUTE = "/"
      TITLE = "abstract"

      attr_accessor :target
      attr_reader :logger, :store, :ignore_patterns

      def initialize(options = {})
        raise NotImplementedError, "#{self.class.name} requires a newer version of Rails" unless self.class.supported_version?
        raise "Coverband: #{self.class.name} initialized before configuration!" if !Coverband.configured? && ENV["COVERBAND_TEST"] == "test"

        @ignore_patterns = Coverband.configuration.ignore
        @store = options.fetch(:store) { Coverband.configuration.store }
        @logger = options.fetch(:logger) { Coverband.configuration.logger }
        @target = options.fetch(:target) do
          concrete_target
        end

        @one_time_timestamp = false

        @logged_keys = Set.new
        @keys_to_record = Set.new
      end

      ###
      # Whether two recordings of the same key combine to the same result.
      # Presence trackers take the later timestamp, so they do; one accumulating
      # counters has to say so, since re-applying a sum double counts and the
      # storage layer picks its layout from this.
      ###
      def self.idempotent_merge?
        true
      end

      def logged_keys
        @logged_keys.to_a
      end

      def keys_to_record
        @keys_to_record.to_a
      end

      ###
      # This method is called on every translation usage
      ###
      def track_key(key)
        if key
          if newly_seen_key?(key)
            @logged_keys << key
            @keys_to_record << key if track_key?(key)
          end
        end
      end

      def used_keys
        return {} unless storage

        storage.entries
      rescue => e
        logger&.error "Coverband: #{self.class.name} failed to read, error #{e.class.name} info #{e.message}"
        {}
      end

      def all_keys
        target.uniq
      end

      def unused_keys(used_keys = nil)
        recently_used_keys = used_keys || self.used_keys
        all_keys.reject { |k| recently_used_keys.key?(k.to_s) }
      end

      def as_json
        used_keys = self.used_keys
        {
          unused_keys: unused_keys(used_keys),
          used_keys: used_keys
        }.to_json
      end

      def tracking_since
        return "N/A" unless storage

        (tracking_time = storage.tracking_since) ? tracking_time.iso8601 : "N/A"
      end

      # local state is dropped by the generation change callback, which only
      # fires once the new pointer is durable; clearing here first would throw
      # away unsaved work on a reset that never landed
      def reset_recordings
        return unless storage

        storage.reset
      end

      def clear_key!(key)
        return unless key
        return unless storage

        storage.delete_entry(key)
        @logged_keys.delete(key)
        @keys_to_record.delete(key)
      end

      # loss the storage layer noticed and repaired as best it could, surfaced so
      # the report can say the numbers are partial rather than imply they are not
      def data_loss
        storage&.data_loss
      end

      # reports this tracker cannot store, so a tab showing nothing can say why
      # rather than reading as an app that used nothing
      def unwritten
        storage&.unwritten
      end

      # exposed so a reporting cycle can batch every pointer read it will make
      def pointer_session
        storage&.pointer_session
      end

      ###
      # States meaning the work is not stored and not held for us. A tracker's
      # own key set is unbounded and re-supplied every cycle, so keeping it is
      # what makes an outage of any length lossless -- where the storage layer's
      # queue is capped, and a key dropped from it can never come back, since
      # this tracker's dedupe set already has it.
      #
      # Anything else means storage took responsibility, and holding a second
      # copy would enqueue the same work twice.
      ###
      UNSTORED_STATES = %i[failed unavailable].freeze

      def save_report
        return unless storage

        forget_deleted_keys
        result = storage.record(delta_to_record)
        @keys_to_record.clear unless UNSTORED_STATES.include?(result)
        recover_dropped_keys
      rescue => e
        # we don't want to raise errors if Coverband can't reach its store.
        # This is a nice to have not a bring the system down
        logger&.error "Coverband: #{self.class.name} failed to store, error #{e.class.name} info #{e.message}"
      end

      # This is the basic rails version supported, if there is something more unique over ride in subclass
      def self.supported_version?
        defined?(Rails::VERSION) && Rails::VERSION::STRING.split(".").first.to_i >= 7
      end

      def route
        self.class::REPORT_ROUTE
      end

      def title
        self.class::TITLE
      end

      protected

      def delta_to_record
        return {} if @keys_to_record.empty?

        reported_time = Time.now.to_i
        @keys_to_record.each_with_object({}) { |key, hash| hash[key.to_s] = reported_time }
      end

      # a key another process cleared has to leave the dedupe set, or a later
      # genuine use of it would never be enqueued again
      def forget_deleted_keys
        storage.newly_tombstoned.each do |key|
          @logged_keys.delete_if { |logged| logged.to_s == key }
          @keys_to_record.delete_if { |pending| pending.to_s == key }
        end
      end

      ###
      # A reset means the operator wants everything gone. An eviction means the
      # backend lost data this process can partly reconstruct, so the keys it
      # already knows are queued to be reported once more rather than forgotten.
      ###
      def drop_local_state!(reason = :reset)
        if reason == :eviction
          @logged_keys.each { |key| @keys_to_record << key if track_key?(key) }
        else
          @logged_keys.clear
          @keys_to_record.clear
        end
      end

      ###
      # Work dropped at the storage caps is gone, and this tracker's dedupe set
      # has already moved on, so those keys would never be reported again: a
      # used view reading as unused. That is the dangerous direction for
      # anything driving deletion, so what is known is queued again, the same
      # way an eviction is handled.
      #
      # Only sound where the merge is idempotent. Re-supplying a summed counter
      # is precisely the double count :retained exists to prevent, so
      # QueryBurstTracker's loss is irreducible and stays reported.
      #
      # Keyed on the loss timestamp so a sustained outage re-supplies once per
      # drop rather than once per cycle.
      ###
      def recover_dropped_keys
        return unless self.class.idempotent_merge?

        loss = storage.data_loss
        return unless loss && loss.kind == :pending_dropped
        return if @recovered_loss_at == loss.at

        @recovered_loss_at = loss.at
        @logged_keys.each { |key| @keys_to_record << key if track_key?(key) }
      end

      def newly_seen_key?(key)
        !@logged_keys.include?(key)
      end

      def track_key?(key, options = {})
        key = key.to_s
        @ignore_patterns.none? { |pattern| key.match?(pattern) }
      end

      ###
      # Presence merging keeps the later of the two timestamps, so applying the
      # same delta twice changes nothing.
      ###
      def merger
        @merger ||= lambda do |doc, delta|
          delta.payload.each do |key, value|
            next if doc.tombstoned?(key, delta.tombstone_epoch)

            existing = doc.payload[key.to_s]
            doc.payload[key.to_s] = value.to_s if existing.nil? || existing.to_i < value.to_i
          end
        end
      end

      def storage
        return @storage if defined?(@storage) && @storage

        factory = store.tracker_storage
        @storage = factory&.for(
          class_key,
          merger: merger,
          idempotent: self.class.idempotent_merge?,
          logger: logger,
          on_generation_change: ->(reason) { drop_local_state!(reason) }
        )
      end

      ###
      # Deprecated: trackers used to reach through the store to raw Redis
      # commands, which is why only Redis backed stores could track anything.
      # Kept for a release so out of tree trackers keep working.
      ###
      def redis_store
        Coverband.configuration.logger&.info(
          "Coverband: #{self.class.name}#redis_store is deprecated, use #storage"
        )
        storage
      end

      private

      def concrete_target
        raise "subclass must implement"
      end

      def class_key
        @class_key ||= self.class.name.split("::").last
      end
    end
  end
end
