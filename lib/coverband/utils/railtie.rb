# frozen_string_literal: true

module Coverband
  class Railtie < Rails::Railtie
    # Coverband needs to be setup before any of the initializers
    # to capture usage of things loaded by them
    # if one uses before_eager_load as I did previously
    # any files that get loaded as part of railties will have no coverage
    config.before_initialize do
      Coverband.configure
      Coverband.configuration.logger&.debug('Railtie setting up Coverband')
      Coverband.start
    end

    initializer 'coverband.configure' do |app|
      app.middleware.use Coverband::Middleware
    end

    config.after_initialize do
      Coverband::Collectors::Coverage.instance.report_coverage(true)
    end

    rake_tasks do
      load 'coverband/utils/tasks.rb'
    end
  end
end
