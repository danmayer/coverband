# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class RedisTest < Minitest::Test
  BASE_KEY = Coverband::Adapters::RedisStore::BASE_KEY

  def setup
    super
    @redis = Redis.new
    @store = Coverband::Adapters::RedisStore.new(@redis)
    @store.clear!
  end

  def test_coverage
    mock_file_hash
    expected = basic_coverage
    @store.save_report(expected)
    assert_equal expected, @store.coverage
  end

  def test_coverage_increments
    mock_file_hash
    expected = basic_coverage.dup
    @store.save_report(basic_coverage.dup)
    assert_equal expected, @store.coverage
    @store.save_report(basic_coverage.dup)
    assert_equal [0, 2, 4], @store.coverage['app_path/dog.rb']
  end

  def test_covered_lines_for_file
    mock_file_hash
    expected = basic_coverage
    @store.save_report(expected)
    assert_equal example_line, @store.covered_lines_for_file('app_path/dog.rb')
  end

  def test_covered_lines_when_null
    assert_equal [], @store.covered_lines_for_file('app_path/dog.rb')
  end

  def test_clear
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
