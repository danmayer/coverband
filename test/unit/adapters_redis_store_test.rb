# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class RedisTest < Test::Unit::TestCase
  BASE_KEY = Coverband::Adapters::RedisStore::BASE_KEY

  def setup
    @redis = Redis.new
    @redis.flushdb
    @store = Coverband::Adapters::RedisStore.new(@redis, array: true)
  end

  def test_coverage
    @redis.sadd(BASE_KEY, 'dog.rb')
    @redis.sadd("#{BASE_KEY}.dog.rb", 1)
    @redis.sadd("#{BASE_KEY}.dog.rb", 2)
    expected = { 'dog.rb' => [1, 2] }
    assert_equal expected, @store.coverage
  end

  def test_covered_lines_for_file
    @redis.sadd("#{BASE_KEY}.dog.rb", 1)
    @redis.sadd("#{BASE_KEY}.dog.rb", 2)
    assert_equal [1, 2], @store.covered_lines_for_file('dog.rb').sort
  end

  def test_covered_lines_for_file__hash
    @redis.mapped_hmset("#{BASE_KEY}.dog.rb", '1' => 1, '2' => 2)
    @store = Coverband::Adapters::RedisStore.new(@redis, array: false)
    expected = [%w[1 1], %w[2 2]]
    assert_equal expected, @store.covered_lines_for_file('dog.rb').sort
  end

  def test_covered_lines_when_null
    assert_equal @store.covered_lines_for_file('dog.rb'), []
  end

  def test_clear
    @redis.expects(:smembers).with(BASE_KEY).once.returns([])
    @redis.expects(:del).with(BASE_KEY).once
    @store.clear!
  end

  private

  def test_data
    {
      '/Users/danmayer/projects/cover_band_server/app.rb' => { 54 => 1, 55 => 2 },
      '/Users/danmayer/projects/cover_band_server/server.rb' => { 5 => 1 }
    }
  end
end

class RedisStoreTestV3Array < RedisTest
  def setup
    @redis = Redis.current.tap do |redis|
      redis.stubs(:sadd).with(anything, anything)
      redis.stubs(:info).returns('redis_version' => 3.0)
    end

    @store = Coverband::Adapters::RedisStore.new(@redis, array: true)
  end

  test 'it stores the files into coverband' do
    @redis.expects(:sadd).with(BASE_KEY, [
                                 '/Users/danmayer/projects/cover_band_server/app.rb',
                                 '/Users/danmayer/projects/cover_band_server/server.rb'
                               ])

    @store.save_report(test_data)
  end

  test 'it stores the file lines of the file app.rb' do
    @redis.expects(:sadd).with(
      "#{BASE_KEY}./Users/danmayer/projects/cover_band_server/app.rb",
      [54, 55]
    )

    @store.save_report(test_data)
  end

  test 'it stores the file lines of the file server.rb' do
    @redis.expects(:sadd).with(
      "#{BASE_KEY}./Users/danmayer/projects/cover_band_server/server.rb",
      [5]
    )

    @store.save_report(test_data)
  end
end

class RedisStoreTestV3Hash < RedisTest
  def setup
    @redis = Redis.current.tap do |redis|
      redis.stubs(:sadd).with(anything, anything)
      redis.stubs(:info).returns('redis_version' => 3.0)
    end

    @store = Coverband::Adapters::RedisStore.new(@redis)
  end

  test 'it stores the files into coverband' do
    @redis.expects(:sadd).with(BASE_KEY, [
                                 '/Users/danmayer/projects/cover_band_server/app.rb',
                                 '/Users/danmayer/projects/cover_band_server/server.rb'
                               ])

    @store.save_report(test_data)
  end

  test 'it stores the file lines of the file app.rb' do
    @redis.expects(:mapped_hmset).with(
      "#{BASE_KEY}./Users/danmayer/projects/cover_band_server/app.rb",
      '54' => 1, '55' => 2
    )
    @redis.expects(:mapped_hmset).with(
      "#{BASE_KEY}./Users/danmayer/projects/cover_band_server/server.rb",
      '5' => 1
    )

    @store.save_report(test_data)
  end
end

class RedisStoreTestV223 < RedisTest
  def setup
    @redis = Redis.current.tap do |redis|
      redis.stubs(:sadd).with(anything, anything)
      redis.stubs(:info).returns('redis_version' => '2.2.3')
    end

    @store = Coverband::Adapters::RedisStore.new(@redis, array: true)
  end

  test 'it store the files with separate calls into coverband' do
    @redis.expects(:sadd).with(BASE_KEY, '/Users/danmayer/projects/cover_band_server/app.rb')
    @redis.expects(:sadd).with(BASE_KEY, '/Users/danmayer/projects/cover_band_server/server.rb')

    @store.save_report(test_data)
  end
end

class RedisStoreTestV222 < RedisTest
  def setup
    @redis = Redis.current.tap do |redis|
      redis.stubs(:sadd).with(anything, anything)
      redis.stubs(:info).returns('redis_version' => '2.2.2')
    end

    @store = Coverband::Adapters::RedisStore.new(@redis, array: true)
  end

  test 'it store the files with separate calls into coverband' do
    @redis.expects(:sadd).with(BASE_KEY, '/Users/danmayer/projects/cover_band_server/app.rb')
    @redis.expects(:sadd).with(BASE_KEY, '/Users/danmayer/projects/cover_band_server/server.rb')

    @store.save_report(test_data)
  end
end
