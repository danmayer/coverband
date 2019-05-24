# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

class RedisTest < Minitest::Test
  REDIS_STORAGE_FORMAT_VERSION = Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION

  def setup
    super
    @redis = Redis.new
    @store = Coverband::Adapters::RedisStore.new(@redis)
  end

  def test_coverage
    mock_file_hash
    expected = basic_coverage
    @store.save_report(expected)
    assert_equal expected.keys, @store.coverage.keys
    @store.coverage.each_pair do |key, data|
      assert_equal expected[key], data['data']
    end
  end

  def test_coverage_increments
    mock_file_hash
    expected = basic_coverage.dup
    @store.save_report(basic_coverage.dup)
    assert_equal expected.keys, @store.coverage.keys
    @store.coverage.each_pair do |key, data|
      assert_equal expected[key], data['data']
    end
    @store.save_report(basic_coverage.dup)
    assert_equal [0, 2, 4], @store.coverage['app_path/dog.rb']['data']
  end

  def test_store_coverage_by_type
    mock_file_hash
    expected = basic_coverage
    @store.type = :eager_loading
    @store.save_report(expected)
    assert_equal expected.keys, @store.coverage.keys
    @store.coverage.each_pair do |key, data|
      assert_equal expected[key], data['data']
    end

    @store.type = nil
    assert_equal [], @store.coverage.keys
  end

  def test_merged_coverage_with_types
    mock_file_hash
    assert_nil @store.type
    @store.type = :eager_loading
    @store.save_report('app_path/dog.rb' => [0, 1, 1])
    @store.type = nil
    @store.save_report('app_path/dog.rb' => [1, 0, 1])
    assert_equal [1, 1, 2], @store.get_coverage_report[:merged]['app_path/dog.rb']['data']
    assert_nil @store.type
  end

  def test_coverage_for_file
    mock_file_hash
    expected = basic_coverage
    @store.save_report(expected)
    assert_equal example_line, @store.coverage['app_path/dog.rb']['data']
  end

  def test_coverage_when_null
    assert_nil @store.coverage['app_path/dog.rb']
  end

  def test_clear
    @redis.expects(:del).twice
    @store.clear!
  end
end
