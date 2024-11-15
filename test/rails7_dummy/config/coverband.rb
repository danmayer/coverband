# frozen_string_literal: true

Coverband.configure do |config|
  # NOTE: we reuse this config in each of the fake rails projects
  # the below ensures the root is set to the correct fake project
  config.root = ::File.expand_path("../../../", __FILE__).to_s + "/rails#{Rails::VERSION::MAJOR}_dummy"
  config.store = Coverband::Adapters::RedisStore.new(Redis.new(db: 2, url: ENV["REDIS_URL"]), redis_namespace: "coverband_test") if defined? Redis
  config.ignore = %w[.erb$ .slim$]
  config.root_paths = []
  config.logger = Rails.logger
  config.verbose = true
  config.background_reporting_enabled = true
  config.track_routes = true
  config.use_oneshot_lines_coverage = true if ENV["ONESHOT"]
end
