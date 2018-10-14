# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class RedisTest < Test::Unit::TestCase
  BASE_KEY = Coverband::Adapters::RedisStore::BASE_KEY

  def setup
    @redis = Redis.new
    @redis.flushdb
    @store = Coverband::Adapters::RedisStore.new(@redis)
  end

  def test_coverage
    expected = basic_coverage
    @store.save_report(expected)
    assert_equal expected, @store.coverage
  end

  def test_coverage_increments
    expected = basic_coverage
    @store.save_report(expected)
    assert_equal expected, @store.coverage
    @store.save_report(expected)
    assert_equal [0, 2, 4], @store.coverage['dog.rb']
  end

  def test_covered_lines_for_file
    expected = basic_coverage
    @store.save_report(expected)
    assert_equal example_line, @store.covered_lines_for_file('dog.rb')
  end

  def test_covered_lines_when_null
    assert_equal nil, @store.covered_lines_for_file('dog.rb')
  end

  def test_clear
    @redis.expects(:del).with(BASE_KEY).once
    @store.clear!
  end

  private

  def combined_report
    {
      "#{BASE_KEY}.dog.rb" => {
        new: example_hash,
        existing: {}
      }
    }
  end

  def test_data
    {
      '/Users/danmayer/projects/cover_band_server/app.rb' => { 54 => 1, 55 => 2 },
      '/Users/danmayer/projects/cover_band_server/server.rb' => { 5 => 1 }
    }
  end
end
