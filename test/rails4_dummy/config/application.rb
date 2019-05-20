# frozen_string_literal: true

require File.expand_path('boot', __dir__)

require 'rails'
require 'action_controller/railtie'
require 'coverband'
Coverband.eager_loading_coverage { Bundler.require(*Rails.groups) }

module Rails4Dummy
  class Application < Rails::Application
    config.eager_load = true
  end
end
