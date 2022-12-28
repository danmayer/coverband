# frozen_string_literal: true

require "set"
require "singleton"

module Coverband
  module Collectors
    module I18n
      module KeyRegistry
        def lookup(locale, key, scope = [], options = {})
          separator = options[:separator] || ::I18n.default_separator
          flat_key = ::I18n.normalize_keys(locale, key, scope, separator).join(separator)
          Coverband.configuration.translations_tracker.track_key(flat_key)

          super
        end
      end
    end

    ###
    # This class tracks translation usage via I18n::Backend
    ###
    class TranslationTracker
      attr_accessor :target
      attr_reader :logger, :store, :ignore_patterns

      def initialize(options = {})
        raise NotImplementedError, "#{self.class.name} requires Rails 4 or greater" unless self.class.supported_version?
        raise "Coverband: #{self.class.name} initialized before configuration!" if !Coverband.configured? && ENV["COVERBAND_TEST"] == "test"

        @ignore_patterns = Coverband.configuration.ignore
        @store = options.fetch(:store) { Coverband.configuration.store }
        @logger = options.fetch(:logger) { Coverband.configuration.logger }
        @target = options.fetch(:target) do
          if defined?(Rails.application)
            # I18n.eager_load!
            # I18n.backend.send(:translations)
            app_translation_keys = []
            app_translation_files = ::I18n.load_path.select { |f| f.match(/config\/locales/) }
            app_translation_files.each do |file|
              app_translation_keys += flatten_hash(YAML.load_file(file)).keys
            end
            app_translation_keys.uniq
          else
            []
          end
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

      def self.supported_version?
        defined?(Rails) && defined?(Rails::VERSION) && Rails::VERSION::STRING.split(".").first.to_i >= 4
      end

      protected

      def newly_seen_key?(key)
        !@logged_keys.include?(key)
      end

      def track_key?(key, options = {})
        @ignore_patterns.none? { |pattern| key.to_s.include?(pattern) }
      end

      private

      def flatten_hash(hash)
        hash.each_with_object({}) do |(k, v), h|
          if v.is_a? Hash
            flatten_hash(v).map do |h_k, h_v|
              h["#{k}.#{h_k}".to_sym] = h_v
            end
          else
            h[k] = v
          end
        end
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
        @class_key ||= self.class.name.split("::").last
      end
    end
  end
end
