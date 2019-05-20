# frozen_string_literal: true

require 'rails'
require 'action_controller/railtie'
require 'coverband'
Coverband.eager_loading_coverage!
Bundler.require(*Rails.groups)
Coverband.report_coverage

module Rails5Dummy
  class Application < Rails::Application
    config.eager_load = true
  end
end
