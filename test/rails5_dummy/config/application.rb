# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "coverband"
Bundler.require(*Rails.groups)

module Rails5Dummy
  class Application < Rails::Application
    config.eager_load = true
    config.consider_all_requests_local = true
  end
end
