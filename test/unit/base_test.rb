require File.expand_path('../test_helper', File.dirname(__FILE__))
require File.expand_path('./dog', File.dirname(__FILE__))

class BaseTest < Test::Unit::TestCase

  test 'defaults to a redis store' do
    coverband = Coverband::Base.instance.reset_instance
    assert_equal Coverband::RedisStore, coverband.instance_variable_get('@reporter').class
  end


  test 'configure memory caching' do
    Coverband.configuration.memory_caching = true
    coverband = Coverband::Base.instance.reset_instance
    assert_equal Coverband::MemoryCacheStore, coverband.instance_variable_get('@reporter').class
    Coverband.configuration.memory_caching = false
  end

  test "start should enable coverage" do
    coverband = Coverband::Base.instance.reset_instance
    assert_equal false, coverband.instance_variable_get("@enabled")
    coverband.expects(:record_coverage).once
    coverband.start
    assert_equal true, coverband.instance_variable_get("@enabled")
  end

  test "extended should default to false" do
    coverband = Coverband::Base.instance.reset_instance
    assert_equal false, coverband.extended?
  end

  test "stop should disable coverage" do
    coverband = Coverband::Base.instance.reset_instance
    assert_equal false, coverband.instance_variable_get("@enabled")
    coverband.expects(:record_coverage).once
    coverband.start
    assert_equal true, coverband.instance_variable_get("@enabled")
    coverband.stop
    assert_equal false, coverband.instance_variable_get("@enabled")
    assert_equal false, coverband.instance_variable_get("@tracer_set")
  end

  test "allow for sampling with a block and enable when 100 percent sample" do
    logger = Logger.new(STDOUT)
    coverband = Coverband::Base.instance.reset_instance
    coverband.instance_variable_set("@sample_percentage", 100.0)
    coverband.instance_variable_set("@verbose", true)
    coverband.instance_variable_set("@logger", logger)
    coverband.instance_variable_set("@reporter", nil)
    assert_equal false, coverband.instance_variable_get("@enabled")
    logger.expects(:info).at_least_once
    coverband.sample { 1 + 1 }
    assert_equal true, coverband.instance_variable_get("@enabled")
  end

  test "allow reporting with start stop save" do
    logger = Logger.new(STDOUT)
    coverband = Coverband::Base.instance.reset_instance
    coverband.instance_variable_set("@sample_percentage", 100.0)
    coverband.instance_variable_set("@verbose", true)
    coverband.instance_variable_set("@logger", logger)
    coverband.instance_variable_set("@reporter", nil)
    assert_equal false, coverband.instance_variable_get("@enabled")
    logger.expects(:info).at_least_once
    coverband.start
    1 + 1
    coverband.stop
    coverband.save
  end

  test "allow reporting to redis start stop save" do
    dog_file = File.expand_path('./dog.rb', File.dirname(__FILE__))
    coverband = Coverband::Base.instance.reset_instance
    coverband.instance_variable_set("@sample_percentage", 100.0)
    coverband.instance_variable_set("@verbose", true)
    store = Coverband::RedisStore.new(Redis.new)
    coverband.instance_variable_set("@reporter", store)
    store.expects(:store_report).once.with(has_entries(dog_file => { 3 => 5 }) )
    assert_equal false, coverband.instance_variable_get("@enabled")
    coverband.start
    5.times { Dog.new.bark }
    coverband.stop
    coverband.save
  end

  test "tracer should count line numbers" do
    dog_file = File.expand_path('./dog.rb', File.dirname(__FILE__))
    coverband = Coverband::Base.instance.reset_instance
    coverband.start
    100.times { Dog.new.bark }
    assert_equal 100, coverband.instance_variable_get("@file_line_usage")[dog_file][3]
    coverband.stop
    coverband.save
  end

end
