require "coverband"
configuration = Coverband.configuration

if configuration.enable_background_tracking
  require 'coverband/background_jobs/sidekiq/server_tracker'
  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add Coverband::BackgroundJobs::Sidekiq::SeverTracker
    end
  end
end