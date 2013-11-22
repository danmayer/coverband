require File.expand_path('../test_helper', File.dirname(__FILE__))

class ReporterTest < Test::Unit::TestCase

  should "record baseline" do
    Coverage.expects(:start).at_least_once
    Coverage.expects(:result).returns({'fake' => [0,1]}).at_least_once
    File.expects(:open).once

    Coverband::Reporter.stubs(:puts)

    Coverband::Reporter.baseline{
      #nothing
    }
  end

  should "report data" do
    Coverband::Reporter.expects(:current_root).returns('/root_dir')
    fake_redis.expects(:smembers).with('coverband').returns(fake_coverband_members)
    Coverband::Reporter.expects('puts').with("fixing root: /root_dir/")
    
    fake_coverband_members.each do |key|
      fake_redis.expects(:smembers).with("coverband.#{key}").returns(["54", "55"])
    end

    matchers = [regexp_matches(/tester/),
                regexp_matches(/application_controller/),
               regexp_matches(/account/),
               regexp_matches(/54/)]
    Coverband::Reporter.expects('puts').with(all_of(*matchers))

    Coverband::Reporter.report(fake_redis, :reporter => 'std_out')
  end

  private

  def fake_redis
    @redis ||= begin
                 redis = OpenStruct.new()
                 def redis.smembers(key)
                 end
                 redis
               end
  end

  def fake_coverband_members
    ["/Users/danmayer/projects/hearno/script/tester.rb",
     "/Users/danmayer/projects/hearno/app/controllers/application_controller.rb",
     "/Users/danmayer/projects/hearno/app/models/account.rb"
    ]
  end

  def fake_coverage_report
    {"/Users/danmayer/projects/hearno/script/tester.rb"=>[1, nil, 1, 1, nil, nil, nil]}
  end

end
