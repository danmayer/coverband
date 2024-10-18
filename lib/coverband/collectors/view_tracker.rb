# frozen_string_literal: true

require "set"
require "singleton"

module Coverband
  module Collectors
    ###
    # This class tracks view file usage via ActiveSupport::Notifications
    #
    # This is a port of Flatfoot, a project I open sourced years ago,
    # but am now rolling into Coverband
    # https://github.com/livingsocial/flatfoot
    ###
    class ViewTracker < AbstractTracker
      attr_reader :roots

      REPORT_ROUTE = "views_tracker"
      TITLE = "Views"
      VIEWS_PATTERNS = %w[.erb$ .haml$ .slim$]

      def initialize(options = {})
        @project_directory = File.expand_path(Coverband.configuration.root)
        @roots = options.fetch(:roots) { Coverband.configuration.all_root_patterns }
        @roots = @roots.split(",") if @roots.is_a?(String)

        super

        @ignore_patterns -= VIEWS_PATTERNS.map { |ignore_str| Regexp.new(ignore_str) }
      end

      def railtie!
        ActiveSupport::Notifications.subscribe(/render_(template|partial|collection).action_view/) do |name, start, finish, id, payload|
          Coverband.configuration.view_tracker.track_key(payload) unless name.include?("!")
        end
      end

      ###
      # This method is called on every render call, so we try to reduce method calls
      # and ensure high performance
      ###
      def track_key(payload)
        if (file = payload[:identifier])
          if newly_seen_key?(file)
            @logged_keys << file
            @keys_to_record << file if track_file?(file)
          end
        end

        ###
        # Annoyingly while you get full path for templates
        # notifications only pass part of the path for layouts dropping any format info
        # such as .html.erb or .js.erb
        # http://edgeguides.rubyonrails.org/active_support_instrumentation.html#render_partial-action_view
        ###
        return unless (layout_file = payload[:layout])
        return unless newly_seen_key?(layout_file)

        @logged_keys << layout_file
        @keys_to_record << layout_file if track_file?(layout_file, layout: true)
      end

      def used_keys
        views = redis_store.hgetall(tracker_key)
        normalized_views = {}
        views.each_pair do |view, time|
          roots.each do |root|
            view = view.gsub(root, "")
          end
          normalized_views[view] = time
        end
        normalized_views
      end

      def all_keys
        all_views = []
        target.each do |view|
          roots.each do |root|
            view = view.gsub(root, "")
          end
          all_views << view
        end
        all_views.uniq
      end

      def unused_keys(used_views = nil)
        recently_used_views = used_keys.keys
        unused_views = all_keys - recently_used_views
        # since layouts don't include format we count them used if they match with ANY formats
        unused_views = unused_views.reject { |view| view.include?("/layouts/") && recently_used_views.any? { |used_view| view.include?(used_view) } }
        unused_views.reject { |view| @ignore_patterns.any? { |pattern| view.match?(pattern) } }
      end

      def clear_key!(filename)
        return unless filename

        filename = "#{@project_directory}/#{filename}"
        redis_store.hdel(tracker_key, filename)
        @logged_keys.delete(filename)
      end

      private

      def track_file?(file, options = {})
        (file.start_with?(@project_directory) || options[:layout]) &&
          @ignore_patterns.none? { |pattern| file.match?(pattern) }
      end

      def concrete_target
        if defined?(Rails.application)
          Dir.glob("#{@project_directory}/app/views/**/*.html.{erb,haml,slim}")
        else
          []
        end
      end
    end
  end
end
