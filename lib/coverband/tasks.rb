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
          Dir.glob("#{Rails.root}/app/models/*.rb").sort.each { |file| require_dependency file }
        end
      }
  end

  desc "report runtime coverband code coverage"
  task :coverage => :environment do
    Coverband::Reporter.report
  end

  desc "reset coverband coverage data"
  task :clear  => :environment do
    Coverband::Reporter.clear_coverage
  end

end
