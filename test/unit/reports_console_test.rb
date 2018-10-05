# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class SimpleCovReportTest < Test::Unit::TestCase
  BASE_KEY = Coverband::Adapters::RedisStore::BASE_KEY

  def setup
    @redis = Redis.new
    @redis.flushdb
    @store = Coverband::Adapters::RedisStore.new(@redis)
  end

  def example_hash
    {'1' => '1', '2' => '2'}
  end

  test 'report data' do
    Coverband.configure do |config|
      config.redis             = @redis
      config.reporter          = 'std_out'
      config.store             = @store
    end
    Coverband.configuration.logger.stubs('info')
    Coverband::Reporters::ConsoleReport.expects(:current_root).returns('./test/unit')

    @redis.sadd(BASE_KEY, 'test/unit/dog.rb')
    @store.send(:store_map, "#{BASE_KEY}.test/unit/dog.rb",
                Digest::MD5.file('test/unit/dog.rb'), example_hash)

    report = Coverband::Reporters::ConsoleReport.report(@store)
    expected = { 'test/unit/dog.rb' => [1, 2, nil, nil, nil, nil, nil] }
    assert_equal(expected, report)
  end
end
