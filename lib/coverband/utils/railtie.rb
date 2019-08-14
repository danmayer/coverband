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
    initializer 'coverband.configure' do |app|
      app.middleware.use Coverband::BackgroundMiddleware

      if Coverband.configuration.track_views
        CoverbandViewTracker = Coverband::Collectors::ViewTracker.new
        Coverband.configuration.view_tracker = CoverbandViewTracker

        ActiveSupport::Notifications.subscribe(/render_partial.action_view|render_template.action_view/) do |name, start, finish, id, payload|
          CoverbandViewTracker.track_views(name, start, finish, id, payload) unless name.include?('!')
        end
      end
    end

    config.after_initialize do
      Coverband.eager_loading_coverage!
      Coverband.report_coverage
      Coverband.runtime_coverage!
    end

    rake_tasks do
      load 'coverband/utils/tasks.rb'
    end
  end
end
