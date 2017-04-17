require "coverband"
configuration = Coverband.configuration

if defined?(Sidekiq)
  require 'coverband/background_jobs/sidekiq/server_tracker'
  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add Coverband::BackgroundJobs::Sidekiq::ServerTracker
    end
  end
end