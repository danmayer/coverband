# frozen_string_literal: true

require "set"
require "singleton"

module Coverband
  module Collectors
    ###
    # This class tracks route usage via ActiveSupport::Notifications
    ###
    class RouteTracker < AbstractTracker
      ###
      # This method is called on every routing call, so we try to reduce method calls
      # and ensure high performance
      ###
      def track_key(payload)
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
          if newly_seen_key?(route)
            @logged_keys << route
            @keys_to_record << route if track_key?(route)
          end
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

      private

      def concrete_target
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
    end
  end
end
