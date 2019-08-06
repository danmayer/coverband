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
