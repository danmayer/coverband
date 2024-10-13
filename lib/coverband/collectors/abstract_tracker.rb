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
        redis_store.hgetall(tracker_key)
      end

      def all_keys
        target.uniq
      end

      def unused_keys(used_keys = nil)
        recently_used_keys = (used_keys || self.used_keys).keys
        all_keys.reject { |k| recently_used_keys.include?(k.to_s) }
      end

      def as_json
        used_keys = self.used_keys
        {
          unused_keys: unused_keys(used_keys),
          used_keys: used_keys
        }.to_json
      end

      def tracking_since
        if (tracking_time = redis_store.get(tracker_time_key))
          Time.at(tracking_time.to_i).iso8601
        else
          "N/A"
        end
      end

      def reset_recordings
        redis_store.del(tracker_key)
        redis_store.del(tracker_time_key)
      end

      def clear_key!(key)
        return unless key
        puts "#{tracker_key} key #{key}"
        redis_store.hdel(tracker_key, key)
        @logged_keys.delete(key)
      end

      def save_report
        redis_store.set(tracker_time_key, Time.now.to_i) unless @one_time_timestamp || tracker_time_key_exists?
        @one_time_timestamp = true
        reported_time = Time.now.to_i
        @keys_to_record.to_a.each do |key|
          redis_store.hset(tracker_key, key.to_s, reported_time)
        end
        @keys_to_record.clear
      rescue => e
        # we don't want to raise errors if Coverband can't reach redis.
        # This is a nice to have not a bring the system down
        logger&.error "Coverband: #{self.class.name} failed to store, error #{e.class.name} info #{e.message}"
      end

      # This is the basic rails version supported, if there is something more unique over ride in subclass
      def self.supported_version?
        defined?(Rails) && defined?(Rails::VERSION) && Rails::VERSION::STRING.split(".").first.to_i >= 5
      end

      def route
        self.class::REPORT_ROUTE
      end

      def title
        self.class::TITLE
      end

      protected

      def newly_seen_key?(key)
        !@logged_keys.include?(key)
      end

      def track_key?(key, options = {})
        key = key.to_s
        @ignore_patterns.none? { |pattern| key.match?(pattern) }
      end

      private

      def concrete_target
        raise "subclass must implement"
      end

      def redis_store
        store.raw_store
      end

      def tracker_time_key_exists?
        if defined?(redis_store.exists?)
          redis_store.exists?(tracker_time_key)
        else
          redis_store.exists(tracker_time_key)
        end
      end

      def tracker_key
        "#{class_key}_tracker"
      end

      def tracker_time_key
        "#{class_key}_tracker_time"
      end

      def class_key
        @class_key ||= if Coverband.configuration.redis_namespace
          "#{Coverband.configuration.redis_namespace}_#{self.class.name.split("::").last}"
        else
          self.class.name.split("::").last
        end
      end
    end
  end
end
