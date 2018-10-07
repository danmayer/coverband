# frozen_string_literal: true
namespace :benchmarks do

  # https://github.com/evanphx/benchmark-ips
  # Enable and start GC before each job run. Disable GC afterwards.
  #
  # Inspired by https://www.omniref.com/ruby/2.2.1/symbols/Benchmark/bm?#annotation=4095926&line=182
  class GCSuite
    def warming(*)
      run_gc
    end

    def running(*)
      run_gc
    end

    def warmup_stats(*)
    end

    def add_report(*)
    end

    private

    def run_gc
      GC.enable
      GC.start
      GC.disable
    end
  end

  def classifier_dir
    File.join(File.dirname(__FILE__), 'classifier-reborn')
  end

  def clone_classifier
    # rubocop:disable Style/IfUnlessModifier
    unless Dir.exist? classifier_dir
      system "git clone git@github.com:jekyll/classifier-reborn.git #{classifier_dir}"
    end
    # rubocop:enable Style/IfUnlessModifier
  end

  desc 'setup standard benchmark'
  task :setup do
    clone_classifier
    $LOAD_PATH.unshift(File.join(classifier_dir, 'lib'))
    require 'benchmark'
    require 'benchmark/ips'

    # TODO ok this is interesting and weird
    # basically the earlier I require coverage and
    # then require files the larger perf impact
    # this is somewhat expected but can lead to significant perf diffs
    # for example moving `require 'classifier-reborn'` below the coverage.start
    # results in 1.5x slower vs "difference falls within error"
    # moving from 5 second of time to 12 still shows slower based on when classifier is required
    # make sure to be plugged in while benchmarking ;) Otherwise you get very unreliable results
    require 'classifier-reborn'
    if ENV['COVERAGE']
      puts 'Coverage library loaded and started'
      require 'coverage'
      ::Coverage.start
    end
    require 'redis'
    require 'coverband'
    require File.join(File.dirname(__FILE__), 'dog')
  end

  desc 'set up coverband tracepoint Redis'
  task :setup_redis do
    Coverband.configure do |config|
      config.redis              = Redis.new
      config.root               = Dir.pwd
      config.percentage         = 100.0
      config.logger             = $stdout
      config.collector          = 'trace'
      config.memory_caching     = ENV['MEMORY_CACHE'] ? true : false
      config.store              = Coverband::Adapters::RedisStore.new(Redis.new)
    end
  end

  desc 'set up coverband tracepoint filestore'
  task :setup_file do
    Coverband.configure do |config|
      config.root               = Dir.pwd
      config.percentage         = 100.0
      config.logger             = $stdout
      config.collector          = 'trace'
      config.memory_caching     = ENV['MEMORY_CACHE'] ? true : false
      config.store              = Coverband::Adapters::FileStore.new('/tmp/benchmark_store.json')
    end
  end

  ###
  # This benchmark always needs to be run last
  # as requiring coverage changes how Ruby interprets the code
  ###
  desc 'set up coverband with coverage Redis'
  task :setup_coverage do
    Coverband.configure do |config|
      config.root               = Dir.pwd
      config.percentage         = 100.0
      config.logger             = $stdout
      config.collector          = 'coverage'
      config.memory_caching     = ENV['MEMORY_CACHE'] ? true : false
      config.store              = Coverband::Adapters::RedisStore.new(Redis.new)
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

  # puts "benchmark for: #{Coverband.configuration.inspect}"
  # puts "store: #{Coverband.configuration.store.inspect}"
  def run_work(hold_work = false)
    suite = GCSuite.new
    Benchmark.ips do |x|
      x.config(time: 12, warmup: 5, suite: suite)
      x.report 'coverband' do
        Coverband::Collectors::Base.instance.sample do
          work
        end
      end
      Coverband::Collectors::Base.instance.stop
      x.report 'no coverband' do
        work
      end
      x.hold! 'temp_results' if hold_work
      x.compare!
    end
    Coverband::Collectors::Base.instance.reset_instance
  end

  def fake_line_numbers
    24.times.each_with_object({}) do |line, line_hash|
      line_hash[(line + 1).to_s] = rand(5)
    end
  end

  def fake_report
    2934.times.each_with_object({}) do |file_number, hash|
      hash["file#{file_number + 1}.rb"] = fake_line_numbers
    end
  end

  def adjust_report(report)
    report.keys.each do |file|
      next unless rand < 0.15
      report[file] = fake_line_numbers
    end
    report
  end

  def reporting_speed
    report = fake_report
    store = Coverband::Adapters::RedisStore.new(Redis.new)

    5.times { store.save_report(report) }
    Benchmark.ips do |x|
      x.config(time: 15, warmup: 5)
      x.report('store_reports') { store.save_report(report) }
    end
  end

  def reporting_memorycache_speed
    report = fake_report
    redis_store = Coverband::Adapters::RedisStore.new(Redis.new)
    cache_store = Coverband::Adapters::MemoryCacheStore.new(redis_store)

    5.times do
      redis_store.save_report(report)
      cache_store.save_report(report)
      adjust_report(report)
    end
    Benchmark.ips do |x|
      x.config(time: 15, warmup: 5)
      x.report('store_redis_reports') do
        redis_store.save_report(report)
        adjust_report(report)
      end
      x.report('store_cache_reports') do
        cache_store.save_report(report)
        adjust_report(report)
      end
      x.compare!
    end
  end

  desc 'runs benchmarks on reporting large files to redis'
  task redis_reporting: [:setup] do
    puts 'runs benchmarks on reporting large files to redis'
    reporting_speed
  end

  desc 'runs benchmarks on reporting large files to redis using memory cache'
  task cache_reporting: [:setup] do
    puts 'runs benchmarks on reporting large files to redis using memory cache'
    reporting_memorycache_speed
  end


  desc 'runs benchmarks on default redis setup'
  task run_redis: [:setup, :setup_redis] do
    puts 'Coverband tracepoint configured with default Redis store'
    run_work
  end

  desc 'runs benchmarks file store'
  task run_file: [:setup, :setup_file] do
    puts 'Coverband tracepoint configured with file store'
    run_work
  end

  desc 'runs benchmarks coverage'
  task run_coverage: [:setup, :setup_coverage] do
    puts 'Coverband Coverage configured with to use default Redis store'
    run_work(true)
  end

  desc 'compare Coverband Ruby Coverage with normal Ruby'
  task :compare_coverage do
    puts 'comparing with Coverage loaded and not, this takes some time for output...'
    puts `COVERAGE=true rake benchmarks:run_coverage`
    puts `rake benchmarks:run_coverage`
  end
end

desc 'runs benchmarks'
task benchmarks: ['benchmarks:run_file', 'benchmarks:run_redis', 'benchmarks:compare_coverage']
