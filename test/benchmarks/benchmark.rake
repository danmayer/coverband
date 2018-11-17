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
      system "git clone https://github.com/jekyll/classifier-reborn.git #{classifier_dir}"
    end
    # rubocop:enable Style/IfUnlessModifier
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
    if ENV['COVERAGE']
      require 'coverage'
      ::Coverage.start
    end
    require 'redis'
    require 'coverband'
    require File.join(File.dirname(__FILE__), 'dog')
  end

  def benchmark_redis_store
    redis = if ENV['REDIS_TEST_URL']
              Redis.new(url: ENV['REDIS_TEST_URL'])
            else
              Redis.new
            end
    Coverband::Adapters::RedisStore.new(redis,
                                        redis_namespace: 'coverband_bench')
  end

  # desc 'set up coverband with Redis'
  task :setup_redis do
    Coverband.configure do |config|
      config.redis               = Redis.new
      config.root                = Dir.pwd
      config.reporting_frequency = 100.0
      config.logger              = $stdout
      config.store               = benchmark_redis_store
    end
  end

  # desc 'set up coverband with filestore'
  task :setup_file do
    Coverband.configure do |config|
      config.root                = Dir.pwd
      config.reporting_frequency = 100.0
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
        Coverband::Collectors::Coverage.instance.report_coverage
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

  def mock_files(store)
    ###
    # this is a hack because in the benchmark we don't have real files
    ###
    def store.file_hash(file)
      if @file_hash_cache[file]
        @file_hash_cache[file]
      else
        @file_hash_cache[file] = Digest::MD5.file(__FILE__).hexdigest
      end
    end
  end

  def reporting_speed
    report = fake_report
    store = benchmark_redis_store
    store.clear!
    mock_files(store)

    5.times { store.save_report(report) }
    Benchmark.ips do |x|
      x.config(time: 15, warmup: 5)
      x.report('store_reports') { store.save_report(report) }
    end
  end

  def measure_memory
    require 'memory_profiler'
    report = fake_report
    store = benchmark_redis_store
    store.clear!
    mock_files(store)

    # warmup
    3.times { store.save_report(report) }

    previous_out = $stdout
    capture = StringIO.new
    $stdout = capture

    MemoryProfiler.report do
      10.times { store.save_report(report) }
    end.pretty_print
    data = $stdout.string
    $stdout = previous_out
    raise 'leaking memory!!!' unless data.match('Total retained:  0 bytes')
  ensure
    $stdout = previous_out
  end

  desc 'runs memory reporting on Redis store'
  task memory_reporting: [:setup] do
    puts 'runs memory benchmarking to ensure we dont leak'
    measure_memory
  end

  desc 'runs benchmarks on reporting large sets of files to redis'
  task redis_reporting: [:setup] do
    puts 'runs benchmarks on reporting large sets of files to redis'
    reporting_speed
  end

  # desc 'runs benchmarks on default redis setup'
  task run_redis: [:setup, :setup_redis] do
    puts 'Coverband configured with default Redis store'
    run_work(true)
  end

  # desc 'runs benchmarks file store'
  task run_file: [:setup, :setup_file] do
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
