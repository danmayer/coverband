namespace :coverband do

  desc "record coverband coverage baseline"
  task :baseline do
    Coverband::Baseline.record {
        if Rake::Task.tasks.any?{ |key| key.to_s.match(/environment$/) }
          Rake::Task['environment'].invoke
        elsif Rake::Task.tasks.any?{ |key| key.to_s.match(/env$/) }
          Rake::Task["env"].invoke
        else
          baseline_files = [File.expand_path('./config/boot.rb',  Dir.pwd),
                            File.expand_path('./config/application.rb', Dir.pwd),
                            File.expand_path('./config/environment.rb', Dir.pwd)]
          
          baseline_files.each do |baseline_file|
                          if File.exists?(baseline_file)
                            require baseline_file
                          end
                        end
        end
        if defined? Rails
          Dir.glob("#{Rails.root}/app/**/*.rb").sort.each { |file| 
              begin
                require_dependency file
              rescue Exception
                #ignore
              end }
          if File.exists?("#{Rails.root}/lib")
            Dir.glob("#{Rails.root}/lib/**/*.rb").sort.each { |file|
              begin
                require_dependency file
              rescue Exception
                #ignoring file
              end}
          end
        end
      }
  end

  ###
  # note: If your project has set many simplecov filters.
  # You might want to override them and clear the filters.
  # Or run the task `coverage_no_filters` below.
  ###
  desc "report runtime coverband code coverage"
  task :coverage => :environment do
    if Coverband.configuration.reporter=='scov'
      Coverband::Reporters::SimpleCovReport.report
    else
      store = Coverband::Adapters::RedisStore.new(Coverband.configuration.redis)
      Coverband::Reporters::ConsoleReport.report(store)
    end
  end

  def clear_simplecov_filters
    if defined? SimpleCov
      SimpleCov.filters.clear
    end
  end

  desc "report runtime coverband code coverage after disabling simplecov filters"
  task :coverage_no_filters => :environment do
    clear_simplecov_filters
    Coverband::Reporters::SimpleCovReport.report
  end

  ###
  # You likely want to clear coverage after significant code changes.
  # You may want to have a hook that saves current coverband data on deploy
  # and then resets the coverband store data.
  ###
  desc "reset coverband coverage data"
  task :clear  => :environment do
    if Coverband.configuration.redis
      Coverband::Adapters::RedisStore.new(Coverband.configuration.redis).clear!
    end
  end

end
