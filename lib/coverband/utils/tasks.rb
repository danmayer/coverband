# frozen_string_literal: true

namespace :coverband do
  Coverband.configure

  def environment
    Rake.application['environment'].invoke if Rake::Task.task_defined?('environment')
  end

  ###
  # NOTE: If your project has set many simplecov filters.
  # You might want to override them and clear the filters.
  # Or run the task `coverage_no_filters` below.
  ###
  desc 'report runtime Coverband code coverage'
  task :coverage do
    environment
    if Coverband.configuration.reporter == 'scov'
      Coverband::Reporters::HTMLReport.report(Coverband.configuration.store)
    else
      Coverband::Reporters::ConsoleReport.report(Coverband.configuration.store)
    end
  end

  desc 'report runtime coverband code coverage after disabling simplecov filters'
  task :coverage_no_filters do
    environment
    if Coverband.configuration.reporter == 'scov'
      clear_simplecov_filters
      Coverband::Reporters::HTMLReport.report(Coverband.configuration.store)
    else
      puts 'coverage without filters only makes sense for SimpleCov reports'
    end
  end

  ###
  # clear data helpful for development or after configuration issues
  ###
  desc 'reset Coverband coverage data, helpful for development, debugging, etc'
  task :clear do
    environment
    Coverband.configuration.store.clear!
  end
end
