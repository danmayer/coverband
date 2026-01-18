# frozen_string_literal: true

require File.expand_path("../test_helper", File.dirname(__FILE__))

class FileStoreRedisErrorTest < Minitest::Test
  def setup
    super
    # Reset the singleton instance to ensure clean state
    Coverband::Collectors::Coverage.instance.reset_instance
  end

  def teardown
    super
    Thread.current[:coverband_instance] = nil
    Coverband.configure do |config|
      # Reset to default redis store
    end
    Coverband::Collectors::Coverage.instance.reset_instance
  end

  test "Default store gracefully handles Redis connection failure" do
    # Clear any existing store configuration
    Coverband.configuration.instance_variable_set(:@store, nil)

    # Mock Redis to simulate connection failure
    Redis.expects(:new).raises(Redis::CannotConnectError.new("Connection refused"))

    # This should not raise an error, instead it should fall back to NullStore
    store = Coverband.configuration.store

    assert_instance_of Coverband::Adapters::NullStore, store
  end

  test "FileStore configuration overrides default store" do
    # Clear any existing store
    Coverband.configuration.instance_variable_set(:@store, nil)

    file_store = Coverband::Adapters::FileStore.new("tmp/test_coverage")
    Coverband.configure do |config|
      config.store = file_store
    end

    assert_same file_store, Coverband.configuration.store
    assert_instance_of Coverband::Adapters::FileStore, Coverband.configuration.store
  end

  test "FileStore is properly set after configuration" do
    store_path = "tmp/test_coverage"
    Coverband.configure do |config|
      config.store = Coverband::Adapters::FileStore.new(store_path)
    end

    assert_instance_of Coverband::Adapters::FileStore, Coverband.configuration.store
    refute Coverband.configuration.store.is_a?(Coverband::Adapters::RedisStore)
  end
end
