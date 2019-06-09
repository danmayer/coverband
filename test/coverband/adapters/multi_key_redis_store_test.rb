# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

class MultiKeyRedisStoreTest < Minitest::Test
  def setup
    super
    @redis = Redis.new
    @redis.flushdb
    @store = Coverband::Adapters::MultiKeyRedisStore.new(@redis, redis_namespace: 'coverband_test')
    Coverband.configuration.store = @store
    mock_file_hash
    @current_time = Time.now
    Time.expects(:now).at_least_once.returns(@current_time)
  end

  def test_coverage_for_file
    @store.save_report(basic_coverage)
    assert_equal example_line, @store.coverage['app_path/dog.rb']['data']
  end

  def test_coverage_for_multiple_files
    data = {
      'app_path/dog.rb' => [0, nil, 1, 2],
      'app_path/cat.rb' => [1, 2, 0, 1, 5]
    }
    @store.save_report(data)
    coverage = @store.coverage
    assert_equal(
      {
        'first_updated_at' => @current_time.to_i,
        'last_updated_at' => @current_time.to_i,
        'file_hash' => 'abcd',
        'data' => [0, nil, 1, 2]
      }, @store.coverage['app_path/dog.rb']
    )
    assert_equal [1, 2, 0, 1, 5], @store.coverage['app_path/cat.rb']['data']
  end
end
