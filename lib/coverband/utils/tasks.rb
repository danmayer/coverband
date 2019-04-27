# frozen_string_literal: true

namespace :coverband do
  Coverband.configure

  def environment
    Rake.application['environment'].invoke if Rake::Task.task_defined?('environment')
  end

  desc 'report runtime Coverband code coverage'
  task :coverage do
    environment
    if Coverband.configuration.reporter == 'scov'
      Coverband::Reporters::HTMLReport.report(Coverband.configuration.store)
    else
      Coverband::Reporters::ConsoleReport.report(Coverband.configuration.store)
    end
  end

  desc 'report runtime Coverband code coverage'
  task :coverage_server do
    environment
    Rack::Server.start app: Coverband::Reporters::Web.new, Port: ENV.fetch('COVERBAND_COVERAGE_PORT', 1022).to_i
  end

  ###
  # clear data helpful for development or after configuration issues
  ###
  desc 'reset Coverband coverage data, helpful for development, debugging, etc'
  task :clear do
    environment
    Coverband.configuration.store.clear!
  end

  ###
  # clear data helpful for development or after configuration issues
  ###
  desc 'upgrade previous Coverband datastore to latest format'
  task :migrate do
    environment
    Coverband.configuration.store.migrate!
  end
end
