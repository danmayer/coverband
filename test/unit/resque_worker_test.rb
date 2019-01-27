# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class ResqueWorkerTest < Minitest::Test
  def enqueue_and_run_job
    Resque.enqueue(TestResqueJob)
    ENV['QUEUE'] ='resque_coverband'
    Resque::Worker.new.work_one_job
  end

  test 'resque job coverage' do
    resque_job_file = File.expand_path('./test_resque_job.rb', File.dirname(__FILE__))
    require resque_job_file

    #report after loading the file in parent process
    Coverband::Collectors::Coverage.instance.report_coverage(true)

    enqueue_and_run_job

    expected = [1, 1, nil, 1, 1, nil, nil]
    assert_equal expected, Coverband.configuration.store.coverage[resque_job_file]['data']
  end
end

