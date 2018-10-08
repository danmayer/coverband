# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))
require File.expand_path('./dummy_checksum_generator', File.dirname(__FILE__))

class RedisTest < Test::Unit::TestCase
  BASE_KEY = Coverband::Adapters::RedisStore::BASE_KEY

  def example_hash
    {'1' => '1', '2' => '2'}
  end

  def setup
    @redis = Redis.new
    @redis.flushdb
    @store = Coverband::Adapters::RedisStore.new(
      @redis,
      checksum_generator: DummyChecksumGenerator.new('fakechecksum')
    )
  end

  def test_invalidation_on_file_change
    @store.instance_variable_set(:@checksum_generator, DummyChecksumGenerator.new('1234'))
    @store.save_report('lib/puppy.rb' => { 54 => 1, 55 => 0 })
    @store.instance_variable_set(:@checksum_generator, DummyChecksumGenerator.new('234'))
    @store.save_report('lib/puppy.rb' => { 54 => 0, 55 => 1 })
    assert_equal({ '54' => '0', '55' => '1' }, @store.covered_lines_for_file('lib/puppy.rb'))
  end

  def test_coverage
    @redis.sadd(BASE_KEY, 'dog.rb')
    @store.send(:store_map, "#{BASE_KEY}.dog.rb", 'fakechecksum', example_hash)
    expected = { 'dog.rb' => example_hash }
    assert_equal expected, @store.coverage
  end

  def test_covered_lines_for_file
    @store.send(:store_map, "#{BASE_KEY}.dog.rb", 'fakechecksum', example_hash)
    assert_equal [["1", "1"], ["2", "2"]], @store.covered_lines_for_file('dog.rb').sort
  end

  def test_covered_lines_for_file_hash
    @redis.mapped_hmset("#{BASE_KEY}.dog.rb", '1' => 1, '2' => 2)
    @store = Coverband::Adapters::RedisStore.new(@redis)
    expected = [%w[1 1], %w[2 2]]
    assert_equal expected, @store.covered_lines_for_file('dog.rb').sort
  end

  def test_covered_lines_when_null
    empty_hash = {}
    assert_equal empty_hash, @store.covered_lines_for_file('dog.rb')
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

class RedisStoreTestV3Hash < RedisTest
  def setup
    @redis = Redis.current.tap do |redis|
      redis.stubs(:sadd).with(anything, anything)
    end
    @redis.flushdb

    @store = Coverband::Adapters::RedisStore.new(@redis, checksum_generator: DummyChecksumGenerator.new('fakechecksum'))
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
      '54' => 1, '55' => 2, 'checksum' => 'fakechecksum'
    )
    @redis.expects(:mapped_hmset).with(
      "#{BASE_KEY}./Users/danmayer/projects/cover_band_server/server.rb",
        '5' => 1, 'checksum' => 'fakechecksum'
    )

    @store.save_report(test_data)
  end
end
