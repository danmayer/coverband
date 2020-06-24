# frozen_string_literal: true

require "singleton"

module Coverband
  module Collectors
    ###
    # This class tracks view file usage via ActiveSupport::Notifications
    #
    # This is a port of Flatfoot, a project I open sourced years ago,
    # but am now rolling into Coverband
    # https://github.com/livingsocial/flatfoot
    #
    # TODO: test and ensure slim, haml, and other support
    ###
    class ViewTracker
      DEFAULT_TARGET = Dir.glob("app/views/**/*.html.erb").reject { |file| file.match(/(_mailer)/) }
      attr_accessor :target, :logged_views, :views_to_record
      attr_reader :logger, :roots, :store, :ignore_patterns

      def initialize(options = {})
        raise NotImplementedError, "View Tracker requires Rails 4 or greater" unless self.class.supported_version?

        @project_directory = File.expand_path(Coverband.configuration.root)
        @ignore_patterns = Coverband.configuration.ignore
        @store = options.fetch(:store) { Coverband.configuration.store }
        @logger = options.fetch(:logger) { Coverband.configuration.logger }
        @target = options.fetch(:target) { DEFAULT_TARGET }

        @roots = options.fetch(:roots) { Coverband.configuration.all_root_patterns }
        @roots = @roots.split(",") if @roots.is_a?(String)
        @one_time_timestamp = false

        @logged_views = []
        @views_to_record = []
      end

      ###
      # This method is called on every render call, so we try to reduce method calls
      # and ensure high performance
      ###
      def track_views(_name, _start, _finish, _id, payload)
        if (file = payload[:identifier])
          if newly_seen_file?(file)
            logged_views << file
            views_to_record << file if track_file?(file)
          end
        end

        ###
        # Annoyingly while you get full path for templates
        # notifications only pass part of the path for layouts dropping any format info
        # such as .html.erb or .js.erb
        # http://edgeguides.rubyonrails.org/active_support_instrumentation.html#render_partial-action_view
        ###
        return unless (layout_file = payload[:layout])
        return unless newly_seen_file?(layout_file)

        logged_views << layout_file
        views_to_record << layout_file if track_file?(layout_file, layout: true)
      end

      def used_views
        views = redis_store.hgetall(tracker_key)
        normalized_views = {}
        views.each_pair do |view, time|
          roots.each do |root|
            view = view.gsub(/#{root}/, "")
          end
          normalized_views[view] = time
        end
        normalized_views
      end

      def unused_views
        recently_used_views = used_views.keys
        all_views = target.reject { |view| recently_used_views.include?(view) }
        # since layouts don't include format we count them used if they match with ANY formats
        all_views.reject { |view| view.match(/\/layouts\//) && recently_used_views.any? { |used_view| view.include?(used_view) } }
      end

      def as_json
        {
          unused_views: unused_views,
          used_views: used_views
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

      def clear_file!(filename)
        return unless filename

        filename = "#{@project_directory}/#{filename}"
        redis_store.hdel(tracker_key, filename)
        logged_views.delete(filename)
      end

      def report_views_tracked
        redis_store.set(tracker_time_key, Time.now.to_i) unless @one_time_timestamp || tracker_time_key_exists?
        @one_time_timestamp = true
        reported_time = Time.now.to_i
        views_to_record.each do |file|
          redis_store.hset(tracker_key, file, reported_time)
        end
        self.views_to_record = []
      rescue => e
        # we don't want to raise errors if Coverband can't reach redis.
        # This is a nice to have not a bring the system down
        logger&.error "Coverband: view_tracker failed to store, error #{e.class.name}"
      end

      def self.supported_version?
        defined?(Rails) && defined?(Rails::VERSION) && Rails::VERSION::STRING.split(".").first.to_i >= 4
      end

      protected

      def newly_seen_file?(file)
        return false if logged_views.include?(file)

        true
      end

      def track_file?(file, options = {})
        @ignore_patterns.none? do |pattern|
          file.include?(pattern)
        end && (file.start_with?(@project_directory) || options[:layout])
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
        "render_tracker_2"
      end

      def tracker_time_key
        "render_tracker_time"
      end
    end
  end
end
