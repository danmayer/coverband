# frozen_string_literal: true

require 'singleton'

module Coverband
  module Collectors
    ###
    # This class tracks view file usage via ActiveSupport::Notifications
    # TODO: The current implementation does this during each request, but this could collect in memory
    # and then push during the Coverband background thread.
    #
    # This is a port of Flatfoot, a project I open sourced years ago, but am now rolling into Coverband
    # https://github.com/livingsocial/flatfoot
    #
    # TODO: add support for ignores, by default ignore view partials in gems
    # TODO: test and ensure slim, haml, and other support
    ###
    class ViewTracker
      DEFAULT_TARGET = Dir.glob('app/views/**/*.html.erb').reject { |file| file.match(/(_mailer)/) }
      attr_accessor :target, :logged_views
      attr_reader :logger, :roots, :store

      def initialize(options = {})
        raise NotImplementedError, 'View Tracker requires Rails 4 or greater' unless self.class.supported_version?

        @ignore_patterns = Coverband.configuration.ignore
        @store = options.fetch(:store) { Coverband.configuration.store }
        @logger = options.fetch(:logger) { Coverband.configuration.logger }
        @target = options.fetch(:target) { DEFAULT_TARGET }

        @roots = options.fetch(:roots) { Coverband.configuration.all_root_patterns }
        @roots = @roots.split(',') if @roots.is_a?(String)
        @logged_views = []
      end

      def track_views(_name, _start, _finish, _id, payload)
        if (file = payload[:identifier])
          if seen_file?(file)
            logged_views << file
            redis_store.sadd(tracker_key, file)
          end
        end
        ###
        # Annoyingly while you get full path for templates
        # notifications only pass part of the path for layouts dropping any format info
        # such as .html.erb or .js.erb
        # http://edgeguides.rubyonrails.org/active_support_instrumentation.html#render_partial-action_view
        ###
        if (layout_file = payload[:layout])
          if seen_file?(layout_file)
            logged_views << layout_file
            redis_store.sadd(tracker_key, layout_file)
          end
        end
      rescue Errno::EAGAIN, Timeout::Error
        # we don't want to raise errors if Coverband can't reach redis. This is a nice to have not a bring the system down
        logger&.error 'Coverband: view_tracker failed to store'
      end

      def used_views
        views = redis_store.smembers(tracker_key)
        normalized_views = []
        views.each do |view|
          roots.each do |root|
            view = view.gsub(/#{root}/, '')
          end
          normalized_views << view
        end
        normalized_views
      end

      def unused_views
        recently_used_views = used_views
        all_views = target.reject { |view| recently_used_views.include?(view) }
        # since layouts don't include format we count them used if they match with ANY formats
        all_views.reject { |view| view.match(/\/layouts\//) && recently_used_views.any? { |used_view| view.include?(used_view) } }
      end

      def reset_recordings
        redis_store.del(tracker_key)
      end

      def self.supported_version?
        defined?(Rails) && defined?(Rails::VERSION) && Rails::VERSION::STRING.split('.').first.to_i >= 4
      end

      def report_views_tracked
      end

      protected

      def seen_file?(file)
        return false if logged_views.include?(file)

        true
        # return true if target.any.match(file)
        # @ignore_patterns.none? do |pattern|
        #   file.include?(pattern)
        # end && (file.start_with?(@project_directory) && target.match(file))
      end

      private

      def redis_store
        store.raw_store
      end

      def tracker_key
        'render_tracker'
      end
    end
  end
end
