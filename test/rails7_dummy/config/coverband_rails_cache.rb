# frozen_string_literal: true

Coverband.configure do |config|
  # Keep Rails.cache lazy: Coverband configuration is loaded before Rails has
  # finished initializing the application's configured cache store.
  config.store = Coverband::Adapters::ActiveSupportCacheStore.new { Rails.cache }
  config.root = ::File.expand_path("../../../", __FILE__).to_s + "/rails#{Rails::VERSION::MAJOR}_dummy"
  config.ignore = %w[.erb$ .slim$]
  config.root_paths = []
  config.logger = Rails.logger
  config.verbose = true
  config.background_reporting_enabled = true
  config.track_routes = true
end
