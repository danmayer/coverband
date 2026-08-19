# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "active_support"
require "active_support/cache"

###
# Adapters differ in what they can actually do, and the rest of Coverband has to
# ask rather than checking classes. These are the answers the web reporter and
# the tracker registration path depend on.
###
class AdapterCapabilitiesTest < Minitest::Test
  def test_persistent_coverage_marks_the_stores_worth_contract_testing
    assert Coverband::Adapters::RedisStore.new(Coverband::Test.redis).persistent_coverage?
    assert Coverband::Adapters::ActiveSupportCacheStore.new(ActiveSupport::Cache::MemoryStore.new).persistent_coverage?
    assert Coverband::Adapters::FileStore.new("/tmp/coverband_capability_test.json").persistent_coverage?

    refute Coverband::Adapters::NullStore.new.persistent_coverage?
    refute Coverband::Adapters::StdoutStore.new.persistent_coverage?
  end

  def test_only_hash_redis_store_pages_reports
    assert Coverband::Adapters::HashRedisStore.new(Coverband::Test.redis).supports_paged_reports?
    refute Coverband::Adapters::ActiveSupportCacheStore.new(ActiveSupport::Cache::MemoryStore.new).supports_paged_reports?

    # COVERBAND_HASH_REDIS_STORE aliases RedisStore to HashRedisStore
    unless Coverband::Adapters::RedisStore == Coverband::Adapters::HashRedisStore
      refute Coverband::Adapters::RedisStore.new(Coverband::Test.redis).supports_paged_reports?
    end
  end

  def test_stores_that_cannot_track_say_so
    refute Coverband::Adapters::NullStore.new.supports_trackers?
    refute Coverband::Adapters::StdoutStore.new.supports_trackers?
    refute Coverband::Adapters::FileStore.new("/tmp/coverband_capability_test.json").supports_trackers?

    assert Coverband::Adapters::RedisStore.new(Coverband::Test.redis).supports_trackers?
    assert Coverband::Adapters::HashRedisStore.new(Coverband::Test.redis).supports_trackers?
    assert Coverband::Adapters::ActiveSupportCacheStore.new(ActiveSupport::Cache::MemoryStore.new).supports_trackers?
  end

  ###
  # FileStore defines neither method, so the web report's datatables path used
  # to raise NoMethodError for anyone not on Redis.
  ###
  def test_file_count_has_a_base_default
    store = Coverband::Adapters::FileStore.new("/tmp/coverband_capability_test_#{rand(10_000)}.json")
    assert_equal 0, store.file_count
    assert_equal 0, store.cached_file_count
  end

  def test_size_in_mib_does_not_treat_an_unknown_size_as_zero
    store = Coverband::Adapters::Base.new
    store.define_singleton_method(:size) { nil }
    assert_equal "N/A", store.size_in_mib

    store.define_singleton_method(:size) { 2**20 }
    assert_equal "1.00", store.size_in_mib
  end

  ###
  # Silently collecting nothing is what file and memcached users used to get.
  ###
  def test_trackers_are_skipped_when_the_store_cannot_support_them
    messages = []
    logger = Object.new
    logger.define_singleton_method(:info) { |message| messages << message }
    logger.define_singleton_method(:error) { |message| messages << message }

    Coverband.configuration.stubs(:logger).returns(logger)
    Coverband.configuration.stubs(:store).returns(Coverband::Adapters::NullStore.new)
    Coverband.configuration.stubs(:track_views).returns(true)

    Coverband.configuration.railtie!

    assert_empty Coverband.configuration.trackers
    assert messages.any? { |message| message.include?("does not support tracking") },
      "the reason has to be stated, not left as an empty tab"
  end
end
