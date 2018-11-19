Coverband.configure do |config|
  config.root              = Dir.pwd
  config.store             = Coverband::Adapters::RedisStore.new(Redis.new(url: ENV['REDIS_URL'])) if defined? Redis
  config.ignore            = %w[vendor .erb$ .slim$]
  config.root_paths        = []
  config.reporting_frequency = 100.0
  config.logger              = Rails.logger
end
