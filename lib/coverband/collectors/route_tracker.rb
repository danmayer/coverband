# frozen_string_literal: true

require "set"
require "singleton"

module Coverband
  module Collectors
    ###
    # This class tracks route usage via ActiveSupport::Notifications
    ###
    class RouteTracker
      attr_accessor :target
      attr_reader :logger, :store, :ignore_patterns

      def initialize(options = {})
        raise NotImplementedError, "Route Tracker requires Rails 4 or greater" unless self.class.supported_version?
        raise "Coverband: route tracker initialized before configuration!" if !Coverband.configured? && ENV["COVERBAND_TEST"] == "test"

        @ignore_patterns = Coverband.configuration.ignore
        @store = options.fetch(:store) { Coverband.configuration.store }
        @logger = options.fetch(:logger) { Coverband.configuration.logger }
        @target = options.fetch(:target) do
          if defined?(Rails.application)
            Rails.application.routes.routes.map do |route|
              {
                controller: route.defaults[:controller],
                action: route.defaults[:action],
                url_path: route.path.spec.to_s.gsub("(.:format)", ""),
                verb: route.verb
              }
            end
          else
            []
          end
        end

        @one_time_timestamp = false

        @logged_routes = Set.new
        @routes_to_record = Set.new
      end

      def logged_routes
        @logged_routes.to_a
      end

      def routes_to_record
        @routes_to_record.to_a
      end

      ###
      # This method is called on every routing call, so we try to reduce method calls
      # and ensure high performance
      ###
      def track_routes(_name, _start, _finish, _id, payload)
        route = if payload[:request]
          {
            controller: nil,
            action: nil,
            url_path: payload[:request].path,
            verb: payload[:request].method
          }
        else
          {
            controller: payload[:params]["controller"],
            action: payload[:action],
            url_path: nil,
            verb: payload[:method]
          }
        end
        if route
          if newly_seen_route?(route)
            @logged_routes << route
            @routes_to_record << route if track_route?(route)
          end
        end
      end

      def used_routes
        redis_store.hgetall(tracker_key)
      end

      def all_routes
        target.uniq
      end

      def unused_routes(used_routes = nil)
        recently_used_routes = (used_routes || self.used_routes).keys
        # NOTE: we match with or without path to handle paths with named params like `/user/:user_id` to used routes filling with all the variable named paths
        all_routes.reject { |r| recently_used_routes.include?(r.to_s) || recently_used_routes.include?(r.merge(url_path: nil).to_s) }
      end

      def as_json
        used_routes = self.used_routes
        {
          unused_routes: unused_routes(used_routes),
          used_routes: used_routes
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

      def clear_route!(route)
        return unless route

        redis_store.hdel(tracker_key, route)
        @logged_routes.delete(route)
      end

      def report_routes_tracked
        redis_store.set(tracker_time_key, Time.now.to_i) unless @one_time_timestamp || tracker_time_key_exists?
        @one_time_timestamp = true
        reported_time = Time.now.to_i
        @routes_to_record.to_a.each do |route|
          redis_store.hset(tracker_key, route.to_s, reported_time)
        end
        @routes_to_record.clear
      rescue => e
        # we don't want to raise errors if Coverband can't reach redis.
        # This is a nice to have not a bring the system down
        logger&.error "Coverband: route_tracker failed to store, error #{e.class.name} info #{e.message}"
      end

      def self.supported_version?
        defined?(Rails) && defined?(Rails::VERSION) && Rails::VERSION::STRING.split(".").first.to_i >= 4
      end

      protected

      def newly_seen_route?(route)
        !@logged_routes.include?(route)
      end

      def track_route?(route, options = {})
        @ignore_patterns.none? { |pattern| route.to_s.include?(pattern) }
      end

      private

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
        "route_tracker_2"
      end

      def tracker_time_key
        "route_tracker_time"
      end
    end
  end
end
