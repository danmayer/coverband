require File.expand_path('../test_helper', File.dirname(__FILE__))

class SimpleCovReportTest < Test::Unit::TestCase

  def setup
    @fake_redis = fake_redis
    @store = Coverband::Adapters::RedisStore.new(@fake_redis, array: true)
  end

  test "report data" do
    Coverband.configure do |config|
      config.reporter          = 'std_out'
    end

    Coverband::Reporters::ConsoleReport.expects(:current_root).returns('/root_dir')
    fake_redis.expects(:smembers).with('coverband').returns(fake_coverband_members)
    
    fake_coverband_members.each do |key|
      fake_redis.expects(:smembers).with("coverband.#{key}").returns(["54", "55"])
    end
    
    Coverband.configuration.logger.stubs('info')

    report = Coverband::Reporters::ConsoleReport.report(@store)
    assert_equal({"/Users/danmayer/projects/hearno/app/controllers/application_controller.rb"=>
                    [54, 55],
                  "/Users/danmayer/projects/hearno/app/models/account.rb"=>[54, 55],
                  "/Users/danmayer/projects/hearno/script/tester.rb"=>[54, 55]},
                 report)
  end

end