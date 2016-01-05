
require 'coverband'
require 'redis'



namespace :benchmarks do

  desc 'set up coverband'
  task :setup do
    $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'classifier-reborn', 'lib'))
    require 'benchmark'
    require 'classifier-reborn'

    Coverband.configure do |config|
      config.redis             = Redis.new
      config.root              = Dir.pwd
      config.startup_delay     = 0
      config.percentage        = 100.0
      config.logger            = $stdout
      config.verbose           = false
    end
  end


  def bayes_classification
    b = ClassifierReborn::Bayes.new 'Interesting', 'Uninteresting'
    b.train_interesting "here are some good words. I hope you love them"
    b.train_uninteresting "here are some bad words, I hate you"
    b.classify "I hate bad words and you" # returns 'Uninteresting'
  end

  def lsi_classification
    lsi = ClassifierReborn::LSI.new
    strings = [ ["This text deals with dogs. Dogs.", :dog],
                ["This text involves dogs too. Dogs! ", :dog],
                ["This text revolves around cats. Cats.", :cat],
                ["This text also involves cats. Cats!", :cat],
                ["This text involves birds. Birds.",:bird ]]
    strings.each {|x| lsi.add_item x.first, x.last}
    lsi.search("dog", 3)
    lsi.find_related(strings[2], 2)
    lsi.classify "This text is also about dogs!"
  end

  def work
    5.times do
      bayes_classification
      lsi_classification
    end
  end



  desc 'runs benchmarks'
  task :run => :setup do
    SAMPLINGS = 3
    bm = Benchmark.bm do |x|

      x.report "coverband" do
        SAMPLINGS.times do
          Coverband::Base.instance.sample do
            work
          end
        end
      end

      x.report "no coverband" do
        SAMPLINGS.times do
          work
        end
      end

    end
  end

end
