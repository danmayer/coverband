# frozen_string_literal: true

require 'pry-byebug'

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

    def warmup_stats(*); end

    def add_report(*); end

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
    system "git clone https://github.com/jekyll/classifier-reborn.git #{classifier_dir}" unless Dir.exist? classifier_dir
  end

  # desc 'setup standard benchmark'
  task :setup do
    clone_classifier
    $LOAD_PATH.unshift(File.join(classifier_dir, 'lib'))
    require 'benchmark'
    require 'benchmark/ips'

    # TODO: ok this is interesting and weird
    # basically the earlier I require coverage and
    # then require files the larger perf impact
    # this is somewhat expected but can lead to significant perf diffs
    # for example moving `require 'classifier-reborn'` below the coverage.start
    # results in 1.5x slower vs "difference falls within error"
    # moving from 5 second of time to 12 still shows slower based on when classifier is required
    # make sure to be plugged in while benchmarking ;) Otherwise you get very unreliable results
    require 'classifier-reborn'
    if ENV['COVERAGE'] || ENV['ONESHOT']
      require 'coverage'
      ::Coverage.start(oneshot_lines: !!ENV['ONESHOT'])
    end
    require 'redis'
    require 'coverband'
    require File.join(File.dirname(__FILE__), 'dog')
  end

  def redis_instance
    require 'logger'
    logger = ENV['REDIS_LOGGING'] ? Logger.new($stdout) : nil
    if ENV['REDIS_TEST_URL']
      Redis.new(url: ENV['REDIS_TEST_URL'], logger: logger)
    else
      Redis.new(logger: logger)
    end
  end

  def benchmark_redis_store(store_type = Coverband::Adapters::RedisStore)
    store_type.new(redis_instance,
                   redis_namespace: 'coverband_bench')
  end

  # desc 'set up coverband with Redis'
  task :setup_redis do
    Coverband.configure do |config|
      config.root                = Dir.pwd
      config.logger              = $stdout
      config.store               = benchmark_redis_store
      config.use_oneshot_lines_coverage = true if ENV['ONESHOT']
      config.simulate_oneshot_lines_coverage = true if ENV['SIMULATE_ONESHOT']
    end
  end

  task :setup_multi_key_redis do
    Coverband.configure do |config|
      config.root                = Dir.pwd
      config.logger              = $stdout
      config.store               = benchmark_redis_store(Coverband::Adapters::MultiKeyRedisStore)
    end
  end

  # desc 'set up coverband with filestore'
  task :setup_file do
    Coverband.configure do |config|
      config.root                = Dir.pwd
      config.logger              = $stdout
      file_path                  = '/tmp/benchmark_store.json'
      config.store               = Coverband::Adapters::FileStore.new(file_path)
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
        work
        Coverband.report_coverage
      end
      x.report 'no coverband' do
        work
      end
      x.hold! 'temp_results' if hold_work
      x.compare!
    end
    Coverband::Collectors::Coverage.instance.reset_instance
  end

  def fake_line_numbers
    24.times.map { rand(5) }
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

  def mock_files(store)
    ###
    # this is a hack because in the benchmark we don't have real files
    ###
    def store.file_hash(file)
      @file_hash_cache[file] || @file_hash_cache[file] = Digest::MD5.file(__FILE__).hexdigest
    end

    def store.full_path_to_relative(file)
      file
    end
  end

  def reporting_speed(store_type = Coverband::Adapters::RedisStore)
    report = fake_report
    store = benchmark_redis_store(store_type)
    store.clear!
    mock_files(store)

    5.times { store.save_report(report) }
    Benchmark.ips do |x|
      x.config(time: 15, warmup: 5)
      x.report('store_reports_all') { store.save_report(report) }
    end

    keys_subset = report.keys.first(100)
    report_subset = report.select { |key, _value| keys_subset.include?(key) }
    Benchmark.ips do |x|
      x.config(time: 20, warmup: 5)
      x.report('store_reports_subset') { store.save_report(report_subset) }
    end
  end

  def measure_memory(store_type = Coverband::Adapters::RedisStore)
    require 'memory_profiler'
    report = fake_report
    store = benchmark_redis_store(store_type)
    store.clear!
    mock_files(store)

    # warmup
    3.times { store.save_report(report) }

    keys_subset = report.keys.first(100)
    report_subset = report.select { |key, _value| keys_subset.include?(key) }
    MemoryProfiler.report do
      2.times { store.save_report(report) }
      25.times { store.save_report(report_subset) }
    end.pretty_print
  end

  def measure_memory_report_coverage
    require 'memory_profiler'
    report = fake_report
    store = benchmark_redis_store
    store.clear!
    mock_files(store)

    # warmup
    3.times { Coverband.report_coverage }

    previous_out = $stdout
    capture = StringIO.new
    $stdout = capture

    MemoryProfiler.report do
      10.times do
        Coverband.report_coverage
        ###
        # Set to nil not {} as it is easier to verify that no memory is retained when nil gets released
        # don't use Coverband::Collectors::Delta.reset which sets to {}
        # we clear this as this one variable is expected to retain memory and is a false positive
        ###
        Coverband::Collectors::Delta.class_variable_set(:@@previous_coverage, nil)
      end
    end.pretty_print
    data = $stdout.string
    $stdout = previous_out
    unless data.match('Total retained:  0 bytes')
      puts data
      raise 'leaking memory!!!'
    end
  ensure
    $stdout = previous_out
  end

  ###
  # TODO: This currently fails, as it holds a string in redis adapter
  # but really Coverband shouldn't be configured multiple times and the leak is small
  # not including in test suite but we can try to figure it out and fix.
  ###
  def measure_configure_memory
    require 'memory_profiler'
    # warmup
    3.times { Coverband.configure }

    previous_out = $stdout
    capture = StringIO.new
    $stdout = capture

    MemoryProfiler.report do
      10.times do
        Coverband.configure do |config|
          redis_url = ENV['CACHE_REDIS_URL'] || ENV['REDIS_URL']
          config.store = Coverband::Adapters::RedisStore.new(Redis.new(url: redis_url), redis_namespace: 'coverband_bench_data')
        end
      end
    end.pretty_print
    data = $stdout.string
    $stdout = previous_out
    unless data.match('Total retained:  0 bytes')
      puts data
      raise 'leaking memory!!!'
    end
  ensure
    $stdout = previous_out
  end

  desc 'checks memory of collector'
  task memory_check: [:setup] do
    require 'pry-byebug'
    require 'objspace'
    puts 'memory load check'
    puts(ObjectSpace.memsize_of_all / 2**20)
    data = File.read('./tmp/debug_data.json')
    # about 2mb
    puts(ObjectSpace.memsize_of(data) / 2**20)

    json_data = JSON.parse(data)
    # this seems to just show the value of the pointer
    # puts(ObjectSpace.memsize_of(json_data) / 2**20)
    # implies json takes 10-12 mb
    puts(ObjectSpace.memsize_of_all / 2**20)

    json_data = nil
    GC.start
    json_data = JSON.parse(data)
    # this seems to just show the value of the pointer
    # puts(ObjectSpace.memsize_of(json_data) / 2**20)
    # implies json takes 10-12 mb
    puts(ObjectSpace.memsize_of_all / 2**20)

    json_data = nil
    GC.start
    json_data = JSON.parse(data)
    # this seems to just show the value of the pointer
    # puts(ObjectSpace.memsize_of(json_data) / 2**20)
    # implies json takes 10-12 mb
    puts(ObjectSpace.memsize_of_all / 2**20)

    json_data = nil
    GC.start
    json_data = JSON.parse(data)
    # this seems to just show the value of the pointer
    # puts(ObjectSpace.memsize_of(json_data) / 2**20)
    # implies json takes 10-12 mb
    puts(ObjectSpace.memsize_of_all / 2**20)

    json_data = nil
    GC.start
    puts(ObjectSpace.memsize_of_all / 2**20)
    debugger
    puts 'done'
  end

  desc 'runs memory reporting on Redis store'
  task memory_reporting: [:setup] do
    puts 'runs memory benchmarking to ensure we dont leak'
    measure_memory
  end

  desc 'runs memory reporting on Redis store'
  task multi_key_memory_reporting: [:setup] do
    puts 'runs memory benchmarking to ensure we dont leak'
    measure_memory(Coverband::Adapters::MultiKeyRedisStore)
  end

  desc 'runs memory reporting on report_coverage'
  task memory_reporting_report_coverage: [:setup] do
    puts 'runs memory benchmarking on report_coverage to ensure we dont leak'
    measure_memory_report_coverage
  end

  desc 'runs memory reporting on configure'
  task memory_configure_reporting: [:setup] do
    puts 'runs memory benchmarking on configure to ensure we dont leak'
    measure_configure_memory
  end

  desc 'runs memory leak check via Rails tests'
  task memory_rails: [:setup] do
    puts 'runs memory rails test to ensure we dont leak'
    puts `COVERBAND_MEMORY_TEST=true bundle exec test/forked/rails_full_stack_test.rb`
  end

  desc 'runs memory leak checks'
  task memory: %i[memory_reporting memory_reporting_report_coverage memory_rails] do
    puts 'done'
  end

  desc 'runs benchmarks on reporting large sets of files to redis'
  task redis_reporting: [:setup] do
    puts 'runs benchmarks on reporting large sets of files to redis'
    reporting_speed
  end

  desc 'runs benchmarks on reporting large sets of files to multi key redis redis'
  task multi_key_redis_reporting: %i[setup] do
    puts 'runs benchmarks on reporting large sets of files to redis'
    reporting_speed(Coverband::Adapters::MultiKeyRedisStore)
  end

  # desc 'runs benchmarks on default redis setup'
  task run_redis: %i[setup setup_redis] do
    puts 'Coverband configured with default Redis store'
    run_work(true)
  end

  task run_big: %i[setup setup_redis] do
    require 'memory_profiler'
    require './test/unique_files'
    # ensure we cleared from last run
    benchmark_redis_store.clear!

    1000.times { require_unique_file }
    # warmup
    3.times { Coverband.report_coverage }
    MemoryProfiler.report do
      10.times { Coverband.report_coverage }
    end.pretty_print
  end

  # desc 'runs benchmarks file store'
  task run_file: %i[setup setup_file] do
    puts 'Coverband configured with file store'
    run_work(true)
  end

  desc 'benchmarks external requests to coverband_demo site'
  task :coverband_demo do
    # for local testing
    # puts `ab -n 500 -c 5 "http://127.0.0.1:3000/posts"`
    puts `ab -n 2000 -c 10 "https://coverband-demo.herokuapp.com/posts"`
  end

  desc 'benchmarks external requests to coverband_demo site'
  task :coverband_demo_graph do
    # for local testing
    # puts `ab -n 200 -c 5 "http://127.0.0.1:3000/posts"`
    # puts `ab -n 500 -c 10 -g tmp/ab_brench.tsv "http://127.0.0.1:3000/posts"`
    puts `ab -n 2000 -c 10 -g tmp/ab_brench.tsv "https://coverband-demo.herokuapp.com/posts"`
    puts `test/benchmarks/graph_bench.sh`
    `open tmp/timeseries.jpg`
  end

  desc 'compare Coverband Ruby Coverage with Filestore with normal Ruby'
  task :compare_file do
    puts 'comparing Coverage loaded/not, this takes some time for output...'
    puts 'coverage loaded'
    puts `COVERAGE=true rake benchmarks:run_file`
    puts 'just the work'
    puts `rake benchmarks:run_file`
  end

  desc 'compare Coverband Ruby Coverage with Redis and normal Ruby'
  task :compare_redis do
    puts 'comparing Coverage loaded/not, this takes some time for output...'
    puts 'coverage loaded'
    puts `COVERAGE=true rake benchmarks:run_redis`
    puts 'just the work'
    puts `rake benchmarks:run_redis`
  end
end

desc 'runs benchmarks'
task benchmarks: ['benchmarks:redis_reporting',
                  'benchmarks:compare_file',
                  'benchmarks:compare_redis']
