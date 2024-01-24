# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class HashRedisStoreTest < Minitest::Test
  REDIS_STORAGE_FORMAT_VERSION = Coverband::Adapters::HashRedisStore::REDIS_STORAGE_FORMAT_VERSION

  class MockRelativeFileConverter
    def self.convert(file)
      file.sub("app_path/", "./")
    end
  end

  def setup
    super
    @redis = Coverband::Test.redis
    # FIXME: remove dependency on configuration and instead pass this in as an argument
    Coverband.configure do |config|
      config.root_paths = ["app_path/"]
    end
    @store = Coverband::Adapters::HashRedisStore.new(@redis, redis_namespace: "coverband_test", relative_file_converter: MockRelativeFileConverter)
    Coverband.configuration.store = @store
  end

  def mock_time(time = Time.now)
    Time.stubs(:now).returns(time)
    time
  end

  def test_no_coverage
    @store.save_report({})
    assert_equal({}, @store.coverage)
  end

  class UnsupportedRedis
    def info
      {"redis_version" => "2.5.0"}
    end
  end

  def test_unsupported_redis
    assert_raises RuntimeError do
      Coverband::Adapters::HashRedisStore.new(UnsupportedRedis.new)
    end
  end

  def test_coverage_for_file
    yesterday = DateTime.now.prev_day.to_time
    today = Time.now
    mock_time(yesterday)
    mock_file_hash
    @store.save_report(
      "app_path/dog.rb" => [0, 1, 2]
    )
    assert_equal(
      {
        "first_updated_at" => yesterday.to_i,
        "last_updated_at" => yesterday.to_i,
        "file_hash" => "abcd",
        "data" => [0, 1, 2]
      },
      @store.coverage["./dog.rb"]
    )
    mock_time(today)
    @store.save_report(
      "app_path/dog.rb" => [1, 1, 0]
    )
    assert_equal(
      {
        "first_updated_at" => yesterday.to_i,
        "last_updated_at" => today.to_i,
        "file_hash" => "abcd",
        "data" => [1, 2, 2]
      },
      @store.coverage["./dog.rb"]
    )
  end

  def test_ttl_set
    mock_file_hash(hash: "abcd")
    @store = Coverband::Adapters::HashRedisStore.new(@redis, redis_namespace: "coverband_test", ttl: 3600, relative_file_converter: MockRelativeFileConverter)
    @store.save_report(
      "app_path/dog.rb" => [0, 1, 2]
    )
    assert_operator(@redis.ttl("#{REDIS_STORAGE_FORMAT_VERSION}.coverband_test.runtime../dog.rb.abcd"), :>, 0)
  end

  def test_no_ttl_set
    mock_file_hash(hash: "abcd")
    @store = Coverband::Adapters::HashRedisStore.new(@redis, redis_namespace: "coverband_test", ttl: nil, relative_file_converter: MockRelativeFileConverter)
    @store.save_report(
      "app_path/dog.rb" => [0, 1, 2]
    )
    assert_equal(-1, @redis.ttl("#{REDIS_STORAGE_FORMAT_VERSION}.coverband_test.runtime../dog.rb.abcd"))
  end

  def test_coverage_for_multiple_files
    current_time = mock_time
    mock_file_hash
    data = {
      "app_path/dog.rb" => [0, nil, 1, 2],
      "app_path/cat.rb" => [1, 2, 0, 1, 5],
      "app_path/ferrit.rb" => [1, 5, nil, 2, nil]
    }
    @store.save_report(data)
    @store.coverage
    assert_equal(
      {
        "first_updated_at" => current_time.to_i,
        "last_updated_at" => current_time.to_i,
        "file_hash" => "abcd",
        "data" => [0, nil, 1, 2]
      }, @store.coverage["./dog.rb"]
    )
    assert_equal [1, 2, 0, 1, 5], @store.coverage["./cat.rb"]["data"]
    assert_equal [1, 5, nil, 2, nil], @store.coverage["./ferrit.rb"]["data"]
  end

  def test_file_hash_change
    mock_file_hash(hash: "abc")
    @store.save_report("app_path/dog.rb" => [0, nil, 1, 2])
    @store.coverage
    assert_equal [0, nil, 1, 2], @store.coverage["./dog.rb"]["data"]
    @store.instance_eval { @file_hash_cache = {} }
    mock_file_hash(hash: "123")
    assert_nil @store.coverage["./dog.rb"]
  end

  def test_type
    mock_file_hash
    @store.type = :eager_loading
    data = {
      "app_path/dog.rb" => [0, nil, 1, 2]
    }
    @store.save_report(data)
    assert_equal 1, @store.coverage.length
    assert_equal [0, nil, 1, 2], @store.coverage["./dog.rb"]["data"]
    # eager_loading doesn't set last_updated_at
    assert_nil @store.coverage["./dog.rb"]["last_updated_at"]
    @store.type = Coverband::RUNTIME_TYPE
    data = {
      "app_path/cat.rb" => [1, 2, 0, 1, 5]
    }
    current_time = Time.now.to_i
    @store.save_report(data)
    assert_equal 1, @store.coverage.length
    assert_equal [1, 2, 0, 1, 5], @store.coverage["./cat.rb"]["data"]
    assert current_time <= @store.coverage["./cat.rb"]["last_updated_at"]
  end

  def test_coverage_type
    mock_file_hash
    @store.type = :eager_loading
    data = {
      "app_path/dog.rb" => [0, nil, 1, 2]
    }
    @store.save_report(data)
    @store.type = Coverband::RUNTIME_TYPE
    assert_equal [0, nil, 1, 2], @store.coverage(:eager_loading)["./dog.rb"]["data"]
  end

  def test_clear
    mock_file_hash
    @store.type = Coverband::EAGER_TYPE
    data = {
      "app_path/dog.rb" => [0, nil, 1, 2]
    }
    @store.save_report(data)
    assert_equal 1, @store.coverage.length
    @store.type = Coverband::RUNTIME_TYPE
    data = {
      "app_path/cat.rb" => [1, 2, 0, 1, 5]
    }
    @store.save_report(data)
    assert_equal 1, @store.coverage.length
    @redis.set("random", "data")
    @store.clear!
    @store.type = Coverband::RUNTIME_TYPE
    assert @store.coverage.empty?
    @store.type = :eager_loading
    assert @store.coverage.empty?
    assert_equal "data", @redis.get("random")
  end

  def test_clear_file
    mock_file_hash
    @store.type = :eager_loading
    @store.save_report("app_path/dog.rb" => [0, 1, 1])
    @store.type = Coverband::RUNTIME_TYPE
    @store.save_report("app_path/dog.rb" => [1, 0, 1])
    assert_equal [1, 1, 2], @store.get_coverage_report[:merged]["./dog.rb"]["data"]
    @store.clear_file!("app_path/dog.rb")
    assert_nil @store.get_coverage_report[:merged]["./dog.rb"]
  end

  def test_get_coverage_cache
    @store = Coverband::Adapters::HashRedisStore.new(
      @redis,
      redis_namespace: "coverband_test",
      relative_file_converter: MockRelativeFileConverter,
      get_coverage_cache: true
    )
    @store.get_coverage_cache.stubs(:deferred_time).returns(0)
    @store.get_coverage_cache.clear!
    mock_file_hash
    yesterday = DateTime.now.prev_day.to_time
    mock_time(yesterday)
    @store.save_report(
      "app_path/dog.rb" => [0, 1, 2]
    )
    assert_equal(
      {
        "first_updated_at" => yesterday.to_i,
        "last_updated_at" => yesterday.to_i,
        "file_hash" => "abcd",
        "data" => [0, 1, 2]
      },
      @store.coverage["./dog.rb"]
    )
    @store.save_report(
      "app_path/dog.rb" => [0, 1, 2]
    )
    assert_equal(
      {
        "first_updated_at" => yesterday.to_i,
        "last_updated_at" => yesterday.to_i,
        "file_hash" => "abcd",
        "data" => [0, 1, 2]
      },
      @store.coverage["./dog.rb"]
    )
    sleep 0.1 # wait caching thread finish
    assert_equal(
      {
        "first_updated_at" => yesterday.to_i,
        "last_updated_at" => yesterday.to_i,
        "file_hash" => "abcd",
        "data" => [0, 2, 4]
      },
      @store.coverage["./dog.rb"]
    )
  end
end
