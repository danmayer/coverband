# frozen_string_literal: true

namespace :coverband do
  # TODO: FixMe before releasing 4.2.1
  # This was previously needed when Coverband was generally require false
  # now this would double configure, which isn't a good thing
  # I think we need ot make it safe to call configure twice and no-op if it has been called
  # because removing this means if you have require: false on coverband or
  # COVERBAND_DISABLE_AUTO_START=true the rake tasks wouldn't work
  # Coverband.configure

  def environment
    Coverband.configuration.report_on_exit = false
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
