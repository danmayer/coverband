# frozen_string_literal: true

namespace :coverband do
  # handles configuring in require => false and COVERBAND_DISABLE_AUTO_START cases
  Coverband.configure unless Coverband.configured?

  desc "report runtime Coverband code coverage"
  task :coverage do
    Coverband::Reporters::ConsoleReport.report(Coverband.configuration.store)
  end

  desc "report runtime Coverband code coverage"
  task :coverage_server do
    Rake.application["environment"].invoke if Rake::Task.task_defined?("environment")
    Coverband.configuration.store.merge_mode = true if Coverband.configuration.store.is_a?(Coverband::Adapters::FileStore)
    Rack::Server.start app: Coverband::Reporters::Web.new, Port: ENV.fetch("COVERBAND_COVERAGE_PORT", 9022).to_i
  end

  ###
  # clear data helpful for development or after configuration issues
  ###
  desc "reset Coverband coverage data, helpful for development, debugging, etc"
  task :clear do
    Coverband.configuration.store.clear!
  end

  ###
  # Updates the data in the coverband store from one format to another
  ###
  desc "upgrade previous Coverband datastore to latest format"
  task :migrate do
    Coverband.configuration.store.migrate!
  end
end
