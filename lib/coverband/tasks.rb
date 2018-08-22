# frozen_string_literal: true

namespace :coverband do
  ###
  # note: If your project has set many simplecov filters.
  # You might want to override them and clear the filters.
  # Or run the task `coverage_no_filters` below.
  ###
  desc 'report runtime coverband code coverage'
  task coverage: :environment do
    if Coverband.configuration.reporter == 'scov'
      Coverband::Reporters::SimpleCovReport.report(Coverband.configuration.store)
    else
      Coverband::Reporters::ConsoleReport.report(Coverband.configuration.store)
    end
  end

  def clear_simplecov_filters
    SimpleCov.filters.clear if defined? SimpleCov
  end

  desc 'report runtime coverband code coverage after disabling simplecov filters'
  task coverage_no_filters: :environment do
    if Coverband.configuration.reporter == 'scov'
      clear_simplecov_filters
      Coverband::Reporters::SimpleCovReport.report(Coverband.configuration.store)
    else
      puts 'coverage without filters only makes sense for SimpleCov reports'
    end
  end

  ###
  # You likely want to clear coverage after significant code changes.
  # You may want to have a hook that saves current coverband data on deploy
  # and then resets the coverband store data.
  ###
  desc 'reset coverband coverage data'
  task clear: :environment do
    Coverband.configuration.store.clear!
  end
end
