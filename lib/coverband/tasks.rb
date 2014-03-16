namespace :coverband do

  desc "record coverband coverage baseline"
  task :baseline do
    Coverband::Reporter.baseline {
      require File.expand_path("../config/environment", __FILE__)
    }
  end

  desc "report runtime coverband code coverage"
  task :coverband => :environment do
    Coverband::Reporter.report
  end

  desc "reset coverband coverage data"
  task :coverband_clear  => :environment do
    Coverband::Reporter.clear_coverage
  end

end
