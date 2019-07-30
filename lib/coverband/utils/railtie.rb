# frozen_string_literal: true

module Coverband
  module RailsEagerLoad
    def eager_load!
      Coverband.eager_loading_coverage!
      super
    ensure
      Coverband.report_coverage
      Coverband.runtime_coverage!
    end
  end
  Rails::Engine.prepend(RailsEagerLoad)

  class Railtie < Rails::Railtie
    initializer 'coverband.configure' do |app|
      app.middleware.use Coverband::BackgroundMiddleware

      if Coverband.configuration.track_views
        # TODO: This isn't a real way to use our stores or get redis fix this.
        CoverbandViewTracker = Coverband::Collectors::ViewTracker.new(Coverband.configuration.store.send(:redis))

        ActiveSupport::Notifications.subscribe /render_partial.action_view|render_template.action_view/ do |name, start, finish, id, payload|
          CoverbandViewTracker.track_views(name, start, finish, id, payload) unless name.include?('!')
        end
      end
    end

    rake_tasks do
      load 'coverband/utils/tasks.rb'
    end
  end
end
