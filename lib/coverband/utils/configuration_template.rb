####
# This is an example coverband configuration file. In a typical Rails app
# it would be placed in config/coverband.rb
#
# Uncomment or adjust the code to your apps needs
####
# Coverband.configure do |config|
####
# set a redis URL and set it with with some reasonable timeouts
####
# redis_url = ENV["COVERBAND_REDIS"] || ENV["REDIS_URL"] || "redis://localhost:6379"
# config.store = Coverband::Adapters::RedisStore.new(
#   Redis.new(
#     url: redis_url,
#     timeout: ENV.fetch("REDIS_TIMEOUT", 1),
#     reconnect_attempts: ENV.fetch("REDIS_RECONNECT_ATTEMPTS", 1),
#     reconnect_delay: ENV.fetch("REDIS_RECONNECT_DELAY", 0.25),
#     reconnect_delay_max: ENV.fetch("REDIS_RECONNECT_DELAY_MAX", 2.5)
#   )
# )

# Allow folks to reset the coverband data via the web UI
# config.web_enable_clear = true

###
# Redis Performance Options. If you running hundreds of web server processes
# you may want to have some controls on how often they are calling redis
# This can help a relatively small Redis handle hundreds / thousands of reporting servers.
###
# reduce the CPU and Redis overhead, we don't need reporting every 30s... This is how often each process will try to save reports
# config.background_reporting_sleep_seconds = 400
# add a wiggle to avoid cache stampede and flatten out Redis CPU...
# This can help if you have many servers restart around a deploy and are all hitting redis at the same time.
# config.reporting_wiggle = 90

# ignore various files for whatever reason. I often ignore the below list as some are setup before coverband and not always
# tracked correctly... Accepts regex or exact match strings.
# config.ignore = %w[config/*
#   config/locales/*
#   config/environments/*
#   config/initializers/*]

# config options false, true, or 'debug'. Always use false in production
# true and debug can give helpful and interesting code usage information
# they both increase the performance overhead of the gem a little.
# they can also help with initially debugging the installation.
# defaults to false
# config.verbose = false

# allow the web UI to display raw coverband data, generally only useful for coverband development
# config.web_debug = true
# end
