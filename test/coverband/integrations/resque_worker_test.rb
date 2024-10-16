# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class ResqueWorkerTest < Minitest::Test
  # NOTE: It appears there are some bugs in resque for JRUBY, not coverband, so excluding these tests on JRUBY
  # if folks hit issues with Coverband and resque this could be a resque issue, reach out with details.
  # I also highly recommend moving to sidekiq.
  unless RUBY_PLATFORM == "java"
    def enqueue_and_run_job
      Resque.enqueue(TestResqueJob)
      ENV["QUEUE"] = "resque_coverband"
      worker = Resque::Worker.new
      worker.startup
      worker.work_one_job
    end

    def setup
      super
      Coverband.configure do |config|
        config.background_reporting_enabled = false
      end
      Coverband.start
      redis = Coverband.configuration.store.instance_eval { @redis }
      Resque.redis = redis
    end

    test "resque job coverage" do
      relative_job_file = "./test/coverband/integrations/test_resque_job.rb"
      resque_job_file = File.expand_path("./test_resque_job.rb", File.dirname(__FILE__))
      require resque_job_file

      enqueue_and_run_job

      assert !Coverband::Background.running?

      # TODO: There is a test only type issue where the test is looking at eager data
      # it merged eager and eager for merged and runtime is eager
      Coverband.runtime_coverage!
      report = Coverband.configuration.store.get_coverage_report

      if RUBY_PLATFORM == "java"
        # NOTE: the todo test only issue seems to be slightly different in JRuby
        # were nothing is showing up as runtime Coverage... This appears to be a test only issue
        assert_equal 1, report[Coverband::EAGER_TYPE][relative_job_file]["data"][6]
      else
        assert_equal 0, report[Coverband::EAGER_TYPE][relative_job_file]["data"][6]
        if report[Coverband::RUNTIME_TYPE] && report[Coverband::RUNTIME_TYPE][relative_job_file]
          assert_equal 1, report[Coverband::RUNTIME_TYPE][relative_job_file]["data"][6]
        end
      end
    end
  end
end
