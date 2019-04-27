# frozen_string_literal: true

Coverband.eager_loading_coverage!
module Coverband
  class Railtie < Rails::Railtie
    initializer 'coverband.configure' do |app|
      app.middleware.use Coverband::Middleware
    end

    config.after_initialize do
      Coverband.report_coverage(true)
      Coverband.configuration.logger&.debug('Coverband: reported after_initialize')
      Coverband.runtime_coverage!
    end

    config.before_initialize do
      Coverband.configuration.logger&.debug('Coverband: set to eager_loading')
      Coverband.eager_loading_coverage!
    end

    rake_tasks do
      load 'coverband/utils/tasks.rb'
    end
  end
end
