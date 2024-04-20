# frozen_string_literal: true

require "set"
require "singleton"

module Coverband
  module Collectors
    ###
    # This class tracks route usage via ActiveSupport::Notifications
    ###
    class RouteTracker < AbstractTracker
      REPORT_ROUTE = "routes_tracker"
      TITLE = "Routes"

      def initialize(options = {})
        if Rails&.respond_to?(:version) && Gem::Version.new(Rails.version) >= Gem::Version.new("6.0.0") && Gem::Version.new(Rails.version) < Gem::Version.new("7.1.0")
          require_relative "../utils/rails6_ext"
        end

        super
      end

      ###
      # This method is called on every routing call, so we try to reduce method calls
      # and ensure high performance
      ###
      def track_key(payload)
        route = if payload.key?(:location)
          # For redirect.action_dispatch
          return unless Coverband.configuration.track_redirect_routes

          {
            controller: nil,
            action: nil,
            url_path: payload[:request].path,
            verb: payload[:request].method
          }
        else
          # For start_processing.action_controller
          {
            controller: payload[:params]["controller"],
            action: payload[:action],
            url_path: nil,
            verb: payload[:method]
          }
        end

        if newly_seen_key?(route)
          @logged_keys << route
          @keys_to_record << route if track_key?(route)
        end
      end

      def self.supported_version?
        defined?(Rails) && defined?(Rails::VERSION) && Rails::VERSION::STRING.split(".").first.to_i >= 6
      end

      def unused_keys(used_keys = nil)
        recently_used_routes = (used_keys || self.used_keys).keys
        # NOTE: we match with or without path to handle paths with named params like `/user/:user_id` to used routes filling with all the variable named paths
        all_keys.reject { |r| recently_used_routes.include?(r.to_s) || recently_used_routes.include?(r.merge(url_path: nil).to_s) }
      end

      def railtie!
        ActiveSupport::Notifications.subscribe("start_processing.action_controller") do |name, start, finish, id, payload|
          Coverband.configuration.route_tracker.track_key(payload)
        end

        # NOTE: This event was instrumented in Aug 10th 2022, but didn't make the 7.0.4 release and should be in the next release
        # https://github.com/rails/rails/pull/43755
        # Automatic tracking of redirects isn't available before Rails 7.1.0 (currently tested against the 7.1.0.alpha)
        # We could consider back porting or patching a solution that works on previous Rails versions
        ActiveSupport::Notifications.subscribe("redirect.action_dispatch") do |name, start, finish, id, payload|
          Coverband.configuration.route_tracker.track_key(payload)
        end
      end

      private

      def concrete_target
        if defined?(Rails.application)
          if Rails.application.respond_to?(:reload_routes!) && Rails.application.routes.empty?
            # NOTE: depending on eager loading etc, routes may not be loaded
            # so load them if they aren't
            Rails.application.reload_routes!
          end
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
    end
  end
end
