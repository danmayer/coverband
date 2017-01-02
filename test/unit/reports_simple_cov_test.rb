require File.expand_path('../test_helper', File.dirname(__FILE__))

class ReportsSimpleCovTest < Test::Unit::TestCase

  def setup
    @fake_redis = fake_redis
    @store = Coverband::Adapters::RedisStore.new(@fake_redis, array: true)
  end

  test "generate scov report" do
    Coverband.configure do |config|
      config.redis             = @fake_redis
      config.reporter          = 'scov'
      config.s3_bucket         = nil
    end

    Coverband::Reporters::SimpleCovReport.expects(:current_root).at_least_once.returns('/root_dir')
    @fake_redis.expects(:smembers).with('coverband').returns(fake_coverband_members)

    SimpleCov.expects(:track_files)
    SimpleCov.expects(:add_not_loaded_files).returns({})
    SimpleCov::Result.any_instance.expects(:format!)

    fake_coverband_members.each do |key|
      File.expects(:exists?).with(key).returns(true)
      File.expects(:foreach).with(key).returns(['a','b','c'])
      @fake_redis.expects(:smembers).with("coverband.#{key}").returns(["54", "55"])
    end
    
    Coverband.configuration.logger.stubs('info')

    Coverband::Reporters::SimpleCovReport.report(@store, open_report: false)
  end

  test "generate scov report with additional data" do
    Coverband.configure do |config|
      config.redis             = @fake_redis
      config.reporter          = 'scov'
      config.s3_bucket         = nil
    end

    Coverband::Reporters::SimpleCovReport.expects(:current_root).at_least_once.returns('/root_dir')
    @fake_redis.expects(:smembers).with('coverband').returns(fake_coverband_members)

    SimpleCov.expects(:track_files)
    SimpleCov.expects(:add_not_loaded_files).returns({})
    SimpleCov::Result.any_instance.expects(:format!)

    fake_coverband_members.each do |key|
      File.expects(:exists?).with(key).returns(true)
      File.expects(:foreach).with(key).returns(['a','b','c'])
      @fake_redis.expects(:smembers).with("coverband.#{key}").returns(["54", "55"])
    end

    Coverband.configuration.logger.stubs('info')
    additional_data = [
      fake_coverage_report
    ]

    Coverband::Reporters::SimpleCovReport.report(@store, open_report: false, additional_scov_data: additional_data)
  end

end
