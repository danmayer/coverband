# frozen_string_literal: true

module Coverband
  class Railtie < Rails::Railtie
    initializer 'coverband.configure' do |app|
      app.middleware.use Coverband::Middleware
    end

    config.after_initialize do
      Coverband.report_coverage(true)
    end

    rake_tasks do
      load 'coverband/utils/tasks.rb'
    end
  end
end
