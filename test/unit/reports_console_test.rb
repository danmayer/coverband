require File.expand_path('../test_helper', File.dirname(__FILE__))

class SimpleCovReportTest < Test::Unit::TestCase

  def setup
    @fake_redis = fake_redis
    @store = Coverband::Adapters::RedisStore.new(@fake_redis, array: true)
  end

  test "report data" do
    Coverband.configure do |config|
      config.redis             = @fake_redis
      config.reporter          = 'std_out'
    end

    Coverband::Reporters::ConsoleReport.expects(:current_root).returns('/tmp/root_dir')
    @fake_redis.expects(:smembers).with('coverband').returns(fake_coverband_members)
    
    fake_coverband_members.each do |key|
      File.expects(:exists?).with(key).returns(true)
      File.expects(:foreach).with(key).returns(Array.new(4){'LOC'})
      @fake_redis.expects(:smembers).with("coverband.#{key}").returns(["1", "3"])
    end
    
    Coverband.configuration.logger.stubs('info')

    report = Coverband::Reporters::ConsoleReport.report(@store)
    expected = {"/Users/danmayer/projects/hearno/app/controllers/application_controller.rb"=>
                  [1, nil, 1, nil],
                "/Users/danmayer/projects/hearno/app/models/account.rb"=>[1, nil, 1, nil],
                "/Users/danmayer/projects/hearno/script/tester.rb"=>[1, nil, 1, nil]}

    assert_equal(expected, report)
  end

end