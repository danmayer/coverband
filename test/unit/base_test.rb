require File.expand_path('../test_helper', File.dirname(__FILE__))

class BaseTest < Test::Unit::TestCase
  
  should "start should enable coverage" do
    coverband = Coverband::Base.new
    assert_equal false, coverband.instance_variable_get("@enabled")
    coverband.expects(:record_coverage).once
    coverband.start
    assert_equal true, coverband.instance_variable_get("@enabled")
  end
  
  should "stop should disable coverage" do
    coverband = Coverband::Base.new
    assert_equal false, coverband.instance_variable_get("@enabled")
    coverband.expects(:record_coverage).once
    coverband.start
    assert_equal true, coverband.instance_variable_get("@enabled")
    coverband.stop
    assert_equal false, coverband.instance_variable_get("@enabled")
    assert_equal false, coverband.instance_variable_get("@function_set")
  end
  
  should "allow for sampling with a block and enable when 100 percent sample" do
    coverband = Coverband::Base.new
    coverband.instance_variable_set("@sample_percentage", 100.0)
    coverband.instance_variable_set("@verbose", true)
    coverband.instance_variable_set("@reporter", nil)
    assert_equal false, coverband.instance_variable_get("@enabled")
    coverband.expects(:puts).at_least_once
    coverband.sample { 1 + 1 }
    assert_equal true, coverband.instance_variable_get("@enabled")
  end
  
  should "allow reporting with start stop save" do
    coverband = Coverband::Base.new
    coverband.instance_variable_set("@sample_percentage", 100.0)
    coverband.instance_variable_set("@verbose", true)
    coverband.instance_variable_set("@reporter", nil)
    assert_equal false, coverband.instance_variable_get("@enabled")
    coverband.expects(:puts).at_least_once
    coverband.start
    1 + 1
    coverband.stop
    coverband.save
  end
  
  should "allow reporting to redis start stop save" do
    coverband = Coverband::Base.new
    coverband.instance_variable_set("@sample_percentage", 100.0)
    coverband.instance_variable_set("@verbose", true)
    fake_redis = Redis.new
    coverband.instance_variable_set("@reporter", fake_redis)
    fake_redis.expects(:sadd).at_least_once
    fake_redis.expects(:sadd).at_least_once.with("coverband./home/action/workspace/coverband/lib/coverband/base.rb", [54, 57, 65, 18, 20, 21, 22, 23])
    assert_equal false, coverband.instance_variable_get("@enabled")
    coverband.start
    1 + 1
    coverband.stop
    coverband.save
  end

end
