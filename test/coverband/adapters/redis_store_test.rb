# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

unless ENV["COVERBAND_HASH_REDIS_STORE"]
  class RedisTest < Minitest::Test
    REDIS_STORAGE_FORMAT_VERSION = Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION

    def setup
      super
      @store = Coverband.configuration.store
      @redis = @store.instance_variable_get(:@redis)
    end

    def test_coverage
      mock_file_hash
      expected = basic_coverage
      @store.save_report(expected)
      assert_equal expected.keys, @store.coverage.keys
      @store.coverage.each_pair do |key, data|
        assert_equal expected[key], data["data"]
      end
    end

    def test_coverage_increments
      mock_file_hash
      expected = basic_coverage.dup
      @store.save_report(basic_coverage.dup)
      assert_equal expected.keys, @store.coverage.keys
      @store.coverage.each_pair do |key, data|
        assert_equal expected[key], data["data"]
      end
      current_time = Time.now.to_i
      @store.save_report(basic_coverage.dup)
      assert_equal [0, 2, 4], @store.coverage["app_path/dog.rb"]["data"]
      assert current_time <= @store.coverage["app_path/dog.rb"]["last_updated_at"]
    end

    def test_file_hash_change
      mock_file_hash(hash: "abc")
      @store.save_report("app_path/dog.rb" => [0, nil, 1, 2])
      assert_equal [0, nil, 1, 2], @store.coverage["app_path/dog.rb"]["data"]
      mock_file_hash(hash: "123")
      assert_nil @store.coverage["app_path/dog.rb"]
    end

    def test_store_coverage_by_type
      mock_file_hash
      expected = basic_coverage
      @store.type = :eager_loading
      @store.save_report(expected)
      assert_equal expected.keys, @store.coverage.keys
      @store.coverage.each_pair do |key, data|
        assert_equal expected[key], data["data"]
      end
      @store.type = Coverband::RUNTIME_TYPE
      assert_equal [], @store.coverage.keys
    end

    def test_merged_coverage_with_types
      mock_file_hash
      assert_equal Coverband::RUNTIME_TYPE, @store.type
      @store.type = :eager_loading
      @store.save_report("app_path/dog.rb" => [0, 1, 1])
      # eager_loading doesn't set last_updated_at
      assert_nil @store.coverage["app_path/dog.rb"]["last_updated_at"]
      @store.type = Coverband::RUNTIME_TYPE
      current_time = Time.now.to_i
      @store.save_report("app_path/dog.rb" => [1, 0, 1])
      assert_equal [1, 1, 2], @store.get_coverage_report[:merged]["app_path/dog.rb"]["data"]
      assert current_time <= @store.coverage["app_path/dog.rb"]["last_updated_at"]
      assert_equal Coverband::RUNTIME_TYPE, @store.type
    end

    def test_coverage_for_file
      mock_file_hash
      expected = basic_coverage
      @store.save_report(expected)
      assert_equal example_line, @store.coverage["app_path/dog.rb"]["data"]
    end

    def test_coverage_when_null
      assert_nil @store.coverage["app_path/dog.rb"]
    end

    def test_clear
      @redis.expects(:del).times(2)
      @store.clear!
    end

    def test_clear_file
      mock_file_hash
      @store.type = :eager_loading
      @store.save_report("app_path/dog.rb" => [0, 1, 1])
      @store.type = Coverband::RUNTIME_TYPE
      @store.save_report("app_path/dog.rb" => [1, 0, 1])
      assert_equal [1, 1, 2], @store.get_coverage_report[:merged]["app_path/dog.rb"]["data"]
      @store.clear_file!("app_path/dog.rb")
      assert_nil @store.get_coverage_report[:merged]["app_path/dog.rb"]
    end

    def test_size
      mock_file_hash
      @store.type = :eager_loading
      @store.save_report("app_path/dog.rb" => [0, 1, 1])
      assert @store.size > 1
    end

    ###
    # redis_ttl still defaults to 30 days, so the configured value has to reach
    # the stored documents. The pointer deliberately never expires: one that
    # outlived its document would leave live coverage unreachable.
    ###
    def test_configured_ttl_applies_to_documents_but_never_pointers
      mock_file_hash
      store = Coverband::Adapters::RedisStore.new(@redis, redis_namespace: "ttl_test", ttl: 120)
      store.save_report(basic_coverage)
      session = store.send(:session_for, Coverband::RUNTIME_TYPE)

      assert_operator @redis.ttl(session.send(:data_key)), :>, 0
      assert_equal(-1, @redis.ttl(session.pointer_key), "the pointer must not expire")
    end

    def test_key_base_is_namespaced_per_type
      key = @store.send(:key_base, Coverband::RUNTIME_TYPE)
      assert key.start_with?(REDIS_STORAGE_FORMAT_VERSION)
      assert key.end_with?(Coverband::RUNTIME_TYPE.to_s)
      refute_equal key, @store.send(:key_base, Coverband::EAGER_TYPE)
    end

    ###
    # Data keys hang off a generation token so a reset retires the whole key
    # rather than racing stale writers for the value inside it.
    ###
    def test_data_keys_are_generation_scoped
      mock_file_hash
      @store.save_report(basic_coverage)
      session = @store.send(:session_for, Coverband::RUNTIME_TYPE)
      assert_match(/\.g[0-9a-f]+\z/, session.send(:data_key))
    end

    def test_reset_retires_the_generation
      mock_file_hash
      @store.save_report(basic_coverage)
      before = @store.send(:session_for, Coverband::RUNTIME_TYPE).generation_token
      @store.clear!
      after = @store.send(:session_for, Coverband::RUNTIME_TYPE).generation_token
      refute_equal before, after
      assert_equal({}, @store.coverage)
    end

    ###
    # The conflict Coverband has always had: two processes read the same
    # coverage, both add to it, and the second write drops the first one's
    # contribution. Applied sequences let the loser notice and re-apply.
    ###
    def test_concurrent_writers_converge_without_double_counting
      mock_file_hash
      # same namespace, so both writers address the same document
      other = Coverband::Adapters::RedisStore.new(@redis, redis_namespace: @store.redis_namespace)

      @store.save_report("app_path/dog.rb" => [1, 0, 0])
      other.save_report("app_path/dog.rb" => [0, 1, 0])

      # settle: any repair happens on a later cycle, and must not inflate
      3.times do
        @store.save_report({})
        other.save_report({})
      end

      assert_equal [1, 1, 0], @store.coverage["app_path/dog.rb"]["data"]
    end
  end
end
