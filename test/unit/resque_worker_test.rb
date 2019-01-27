# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class ResqueWorkerTest < Minitest::Test
  def enqueue_and_run_job
    Resque.enqueue(TestResqueJob)
    queue = ENV['QUEUE'] ='resque_coverband'
    10.times do
      break if Resque.size(queue) == 1
      puts "sleeping until queue size is 1"
    end
    raise "Job not enqueued" if Resque.size(queue) != 1
    25.times do
      Resque::Worker.new.work_one_job
      break if Resque.size(queue) == 0
      puts "sleeping until queue size is 0"
      sleep 0.25
    end
    raise "Job did not run" if Resque.size(queue) != 0
    sleep 0.5
  end

  def setup
    super
    redis = Coverband.configuration.store.send(:redis)
    Resque.redis = redis
  end

  test 'resque job coverage' do
    resque_job_file = File.expand_path('./test_resque_job.rb', File.dirname(__FILE__))
    require resque_job_file

    #report after loading the file in parent process
    Coverband::Collectors::Coverage.instance.report_coverage(true)

    enqueue_and_run_job

    puts "assert_equal 1, Coverband.configuration.store.coverage['#{resque_job_file}']['data'][4]"
    assert_equal 1, Coverband.configuration.store.coverage[resque_job_file]['data'][4]
  end
end

