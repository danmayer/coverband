# frozen_string_literal: true

require File.expand_path('boot', __dir__)

require 'rails'
require 'action_controller/railtie'
module Rails4Dummy
  class Application < Rails::Application
    # Coverband needs to be setup before any of the initializers to capture usage of them
    Coverband.configure(File.open("#{Rails.root}/config/coverband.rb"))
    config.middleware.use Coverband::BackgroundMiddleware
    config.before_initialize do
      Coverband.start
    end
    config.eager_load = true
  end
end
