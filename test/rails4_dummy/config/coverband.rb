Coverband.configure do |config|
  config.root              = Dir.pwd
  config.store             = Coverband::Adapters::RedisStore.new(Redis.new(url: ENV['REDIS_URL'])) if defined? Redis
  config.ignore            = %w[vendor .erb$ .slim$]
  config.root_paths        = []
  config.logger              = Rails.logger
  config.background_reporting_sleep_seconds = 0.01
end
