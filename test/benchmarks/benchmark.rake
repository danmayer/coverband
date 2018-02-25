# frozen_string_literal: true

require 'coverband'
require 'redis'
require File.join(File.dirname(__FILE__), 'dog')

namespace :benchmarks do
  def classifier_dir
    classifier_dir = File.join(File.dirname(__FILE__), 'classifier-reborn')
  end

  def clone_classifier
    unless Dir.exist? classifier_dir
      system "git clone git@github.com:jekyll/classifier-reborn.git #{classifier_dir}"
    end
  end

  desc 'set up coverband default redis'
  task :setup do
    clone_classifier
    $LOAD_PATH.unshift(File.join(classifier_dir, 'lib'))
    require 'benchmark'
    require 'classifier-reborn'

    Coverband.configure do |config|
      config.redis              = Redis.new
      config.root               = Dir.pwd
      config.startup_delay      = 0
      config.percentage         = 100.0
      config.logger             = $stdout
      config.verbose            = false
      # config.memory_caching     = true
      # config.trace_point_events = [:call]
    end
  end

  desc 'set up coverband redis array'
  task :setup_array do
    clone_classifier
    $LOAD_PATH.unshift(File.join(classifier_dir, 'lib'))
    require 'benchmark'
    require 'classifier-reborn'

    Coverband.configure do |config|
      config.redis              = Redis.new
      config.root               = Dir.pwd
      config.startup_delay      = 0
      config.percentage         = 100.0
      config.logger             = $stdout
      config.verbose            = false
      config.store              = Coverband::Adapters::RedisStore.new(Redis.new, array: true)
    end
  end

  desc 'set up coverband filestore'
  task :setup_file do
    clone_classifier
    $LOAD_PATH.unshift(File.join(classifier_dir, 'lib'))
    require 'benchmark'
    require 'classifier-reborn'

    Coverband.configure do |config|
      config.redis              = nil
      config.store              = nil
      config.root               = Dir.pwd
      config.startup_delay      = 0
      config.percentage         = 100.0
      config.logger             = $stdout
      config.verbose            = false
      config.coverage_file = '/tmp/benchmark_store.json'
    end
  end

  def bayes_classification
    b = ClassifierReborn::Bayes.new 'Interesting', 'Uninteresting'
    b.train_interesting 'here are some good words. I hope you love them'
    b.train_uninteresting 'here are some bad words, I hate you'
    b.classify 'I hate bad words and you' # returns 'Uninteresting'
  end

  def lsi_classification
    lsi = ClassifierReborn::LSI.new
    strings = [['This text deals with dogs. Dogs.', :dog],
               ['This text involves dogs too. Dogs! ', :dog],
               ['This text revolves around cats. Cats.', :cat],
               ['This text also involves cats. Cats!', :cat],
               ['This text involves birds. Birds.', :bird]]
    strings.each { |x| lsi.add_item x.first, x.last }
    lsi.search('dog', 3)
    lsi.find_related(strings[2], 2)
    lsi.classify 'This text is also about dogs!'
  end

  def work
    5.times do
      bayes_classification
      lsi_classification
    end

    # simulate many calls to the same line
    10_000.times { Dog.new.bark }
  end

  def run_work
    puts "benchmark for: #{Coverband.configuration.inspect}"
    puts "store: #{Coverband.configuration.store.inspect}"
    bm = Benchmark.bm(15) do |x|
      x.report 'coverband' do
        SAMPLINGS.times do
          Coverband::Base.instance.sample do
            work
          end
        end
      end

      x.report 'no coverband' do
        SAMPLINGS.times do
          work
        end
      end
    end
  end

  desc 'runs benchmarks on default redis setup'
  task run: :setup do
    SAMPLINGS = 5
    run_work
  end

  desc 'runs benchmarks redis array'
  task run_array: :setup_array do
    SAMPLINGS = 5
    run_work
  end

  desc 'runs benchmarks file store'
  task run_file: :setup_file do
    SAMPLINGS = 5
    run_work
  end
end

desc 'runs benchmarks'
task benchmarks: ['benchmarks:run']
