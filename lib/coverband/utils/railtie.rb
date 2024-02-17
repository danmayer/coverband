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
      app.middleware.use Coverband::BackgroundMiddleware
    rescue Redis::CannotConnectError => error
      Coverband.configuration.logger.info "Redis is not available (#{error}), Coverband not configured"
      Coverband.configuration.logger.info "If this is a setup task like assets:precompile feel free to ignore"
    end

    config.after_initialize do
      unless Coverband.tasks_to_ignore?
        Coverband.configure unless Coverband.configured?
        Coverband.eager_loading_coverage!
        Coverband.report_coverage
        Coverband.runtime_coverage!
      end

      Coverband.configuration.railtie!
    end

    config.before_configuration do
      unless ENV["COVERBAND_DISABLE_AUTO_START"]
        begin
          Coverband.configure unless Coverband.configured?
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
