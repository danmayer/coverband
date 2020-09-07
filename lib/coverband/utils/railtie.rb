# frozen_string_literal: true

module Coverband
  module RailsEagerLoad
    def eager_load!
      Coverband.eager_loading_coverage!
      super
    end
  end
  Rails::Engine.prepend(RailsEagerLoad)

  class Railtie < Rails::Railtie
    initializer "coverband.configure" do |app|
      begin
        app.middleware.use Coverband::BackgroundMiddleware
      rescue Redis::CannotConnectError => error
        Coverband.configuration.logger.info "Redis is not available (#{error}), Coverband not configured"
        Coverband.configuration.logger.info "If this is a setup task like assets:precompile feel free to ignore"
      end
    end

    config.after_initialize do
      unless Coverband.tasks_to_ignore?
        Coverband.configure
        Coverband.eager_loading_coverage!
        Coverband.report_coverage
        Coverband.runtime_coverage!
      end

      begin
        if Coverband.configuration.track_views
          COVERBAND_VIEW_TRACKER = if Coverband.coverband_service?
            Coverband::Collectors::ViewTrackerService.new
          else
            Coverband::Collectors::ViewTracker.new
          end

          Coverband.configuration.view_tracker = COVERBAND_VIEW_TRACKER

          ActiveSupport::Notifications.subscribe(/render_partial.action_view|render_template.action_view/) do |name, start, finish, id, payload|
            COVERBAND_VIEW_TRACKER.track_views(name, start, finish, id, payload) unless name.include?("!")
          end
        end
      rescue Redis::CannotConnectError => error
        Coverband.configuration.logger.info "Redis is not available (#{error}), Coverband not configured"
        Coverband.configuration.logger.info "If this is a setup task like assets:precompile feel free to ignore"
      end
    end

    config.before_configuration do
      unless ENV["COVERBAND_DISABLE_AUTO_START"]
        begin
          Coverband.start
        rescue Redis::CannotConnectError => error
          Coverband.configuration.logger.info "Redis is not available (#{error}), Coverband not configured"
          Coverband.configuration.logger.info "If this is a setup task like assets:precompile feel free to ignore"
        end
      end
    end

    rake_tasks do
      load "coverband/utils/tasks.rb"
    end
  end
end
