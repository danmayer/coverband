# frozen_string_literal: true

Coverband.configure do |config|
  config.root = Dir.pwd
  config.store = Coverband::Adapters::RedisStore.new(Redis.new(db: 2, url: "redis://127.0.0.1:123"), redis_namespace: "coverband_test") if defined? Redis
  config.ignore = %w[vendor .erb$ .slim$]
  config.root_paths = []
  config.logger = Rails.logger
  config.verbose = true
  config.background_reporting_enabled = true
  config.track_gems = true
  config.gem_details = true
  config.use_oneshot_lines_coverage = true if ENV["ONESHOT"]
end
