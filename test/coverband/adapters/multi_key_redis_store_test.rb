# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

class MultiKeyRedisStoreTest < Minitest::Test
  def setup
    super
    @redis = Redis.new
    # FIXME: remove dependency on configuration and instead pass this in as an argument
    Coverband.configure do |config|
      config.root_paths = ['app_path/']
    end
    @store = Coverband::Adapters::MultiKeyRedisStore.new(@redis, redis_namespace: 'coverband_test')
    @store.clear!
    Coverband.configuration.store = @store
  end

  def mock_time
    @current_time = Time.now
    Time.stubs(:now).returns(@current_time)
  end

  def test_no_coverage
    @store.save_report({})
    assert_equal({}, @store.coverage)
  end

  def test_coverage_for_file
    mock_time
    mock_file_hash
    @store.save_report(
      'app_path/dog.rb' => [0, 1, 2]
    )
    assert_equal example_line, @store.coverage['./dog.rb']['data']
    assert_equal(
      {
        'first_updated_at' => @current_time.to_i,
        'last_updated_at' => @current_time.to_i,
        'file_hash' => 'abcd',
        'data' => [0, 1, 2]
      },
      @store.coverage['./dog.rb']
    )
    @store.save_report(
      'app_path/dog.rb' => [1, 1, 0]
    )
    assert_equal(
      {
        'first_updated_at' => @current_time.to_i,
        'last_updated_at' => @current_time.to_i,
        'file_hash' => 'abcd',
        'data' => [1, 2, 2]
      },
      @store.coverage['./dog.rb']
    )
  end

  def test_coverage_for_multiple_files
    mock_time
    mock_file_hash
    data = {
      'app_path/dog.rb' => [0, nil, 1, 2],
      'app_path/cat.rb' => [1, 2, 0, 1, 5],
      'app_path/ferrit.rb' => [1, 5, nil, 2]
    }
    @store.save_report(data)
    coverage = @store.coverage
    assert_equal(
      {
        'first_updated_at' => @current_time.to_i,
        'last_updated_at' => @current_time.to_i,
        'file_hash' => 'abcd',
        'data' => [0, nil, 1, 2]
      }, @store.coverage['./dog.rb']
    )
    assert_equal [1, 2, 0, 1, 5], @store.coverage['./cat.rb']['data']
    assert_equal [1, 5, nil, 2], @store.coverage['./ferrit.rb']['data']
  end

  def test_coverage_subset
    mock_file_hash
    data = {
      'app_path/dog.rb' => [0, nil, 1, 2],
      'app_path/cat.rb' => [1, 2, 0, 1, 5],
      'app_path/ferrit.rb' => [1, 5, nil, 2]
    }
    @store.save_report(data)
    coverage = @store.coverage(files: ['./cat.rb', './ferrit.rb'])
    assert_equal 2, coverage.length
    assert_equal [1, 2, 0, 1, 5], @store.coverage['./cat.rb']['data']
    assert_equal [1, 5, nil, 2], @store.coverage['./ferrit.rb']['data']
  end

  def test_type
    mock_file_hash
    @store.type = :eager_loading
    data = {
      'app_path/dog.rb' => [0, nil, 1, 2]
    }
    @store.save_report(data)
    assert_equal 1, @store.coverage.length
    assert_equal [0, nil, 1, 2], @store.coverage['./dog.rb']['data']
    @store.type = Coverband::RUNTIME_TYPE
    data = {
      'app_path/cat.rb' => [1, 2, 0, 1, 5]
    }
    @store.save_report(data)
    assert_equal 1, @store.coverage.length
    assert_equal [1, 2, 0, 1, 5], @store.coverage['./cat.rb']['data']
  end

  def test_coverage_type
    mock_file_hash
    @store.type = :eager_loading
    data = {
      'app_path/dog.rb' => [0, nil, 1, 2]
    }
    @store.save_report(data)
    @store.type = nil
    assert_equal [0, nil, 1, 2], @store.coverage(:eager_loading)['./dog.rb']['data']
  end

  def test_clear
    mock_file_hash
    @store.type = Coverband::EAGER_TYPE
    data = {
      'app_path/dog.rb' => [0, nil, 1, 2]
    }
    @store.save_report(data)
    assert_equal 1, @store.coverage.length
    @store.type = Coverband::RUNTIME_TYPE
    data = {
      'app_path/cat.rb' => [1, 2, 0, 1, 5]
    }
    @store.save_report(data)
    assert_equal 1, @store.coverage.length
    @redis.set('random', 'data')
    @store.clear!
    @store.type = Coverband::RUNTIME_TYPE
    assert @store.coverage.empty?
    @store.type = :eager_loading
    assert @store.coverage.empty?
    assert_equal 'data', @redis.get('random')
  end
end
