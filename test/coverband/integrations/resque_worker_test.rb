# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

class ResqueWorkerTest < Minitest::Test
  def enqueue_and_run_job
    Resque.enqueue(TestResqueJob)
    queue = ENV['QUEUE'] ='resque_coverband'
    worker = Resque::Worker.new
    worker.startup
    worker.work_one_job
  end

  def setup
    super
    Coverband.configure do |config|
      config.background_reporting_enabled = false
      config.root_paths = ["#{File.expand_path('../', File.dirname(__FILE__))}/"]
    end
    Coverband.start
    redis = Coverband.configuration.store.send(:redis)
    Resque.redis = redis
  end

  test 'resque job coverage' do
    relative_job_file = './unit/test_resque_job.rb'
    resque_job_file = File.expand_path('./test_resque_job.rb', File.dirname(__FILE__))
    require resque_job_file

    enqueue_and_run_job

    assert !Coverband::Background.running?

    assert_equal 1, Coverband.configuration.store.coverage[relative_job_file]['data'][4]
  end
end
