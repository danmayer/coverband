# frozen_string_literal: true

require 'rails'
require 'action_controller/railtie'
require 'coverband'
Bundler.require(*Rails.groups)

module Rails5Dummy
  class Application < Rails::Application
    config.eager_load = true
  end
end
