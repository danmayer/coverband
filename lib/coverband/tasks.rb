namespace :coverband do

  desc "record coverband coverage baseline"
  task :baseline do
    Coverband::Reporter.baseline {
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
              rescue
                #ignore
              end }
        end
        if File.exists?("#{Rails.root}/lib")
          Dir.glob("#{Rails.root}/lib/**/*.rb").sort.each { |file| begin
                                                                require_dependency file
                                                              rescue
                                                                #ignoring file
                                                              end}
        end
      }
  end

  ###
  # note: If have set a ton of simplecov filters you might want to override them and clear the filters or run the task below.
  ###
  desc "report runtime coverband code coverage"
  task :coverage => :environment do
                   Coverband::Reporter.report
  end

  def clear_simplecov_filters
    if defined? SimpleCov
      SimpleCov.filters.clear
    end
  end

  desc "report runtime coverband code coverage"
  task :coverage_no_filters => :environment do
    clear_simplecov_filters
    Coverband::Reporter.report
  end

  desc "reset coverband coverage data"
  task :clear  => :environment do
    Coverband::Reporter.clear_coverage
  end

end
