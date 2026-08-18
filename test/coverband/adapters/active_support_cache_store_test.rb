# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "active_support"
require "active_support/cache"

###
# The same adapter behaviour has to hold on every cache backend, so the cases
# are written once and run against each store we can reach.
#
# MemoryStore is per process and only useful for tests; FileStore needs no
# services so it runs everywhere; memcached runs when CI provides it.
###
module ActiveSupportCacheStoreBehavior
  def build_store(opts = {})
    Coverband::Adapters::ActiveSupportCacheStore.new(cache, {cache_namespace: "coverband_test"}.merge(opts))
  end

  def test_coverage_round_trip
    mock_file_hash
    @store.save_report(basic_coverage)
    assert_equal basic_coverage.keys, @store.coverage.keys
    assert_equal example_line, @store.coverage["app_path/dog.rb"]["data"]
  end

  def test_coverage_increments
    mock_file_hash
    @store.save_report(basic_coverage.dup)
    @store.save_report(basic_coverage.dup)
    assert_equal [0, 2, 4], @store.coverage["app_path/dog.rb"]["data"]
  end

  def test_coverage_by_type_is_isolated
    mock_file_hash
    @store.type = :eager_loading
    @store.save_report(basic_coverage)
    assert_equal basic_coverage.keys, @store.coverage.keys
    @store.type = Coverband::RUNTIME_TYPE
    assert_equal [], @store.coverage.keys
  end

  def test_merged_coverage_with_types
    mock_file_hash
    @store.type = :eager_loading
    @store.save_report("app_path/dog.rb" => [0, 1, 1])
    @store.type = Coverband::RUNTIME_TYPE
    @store.save_report("app_path/dog.rb" => [1, 0, 1])
    assert_equal [1, 1, 2], @store.get_coverage_report[:merged]["app_path/dog.rb"]["data"]
  end

  def test_file_hash_change_hides_stale_coverage
    mock_file_hash(hash: "abc")
    @store.save_report("app_path/dog.rb" => [0, nil, 1, 2])
    assert_equal [0, nil, 1, 2], @store.coverage["app_path/dog.rb"]["data"]
    mock_file_hash(hash: "123")
    assert_nil @store.coverage["app_path/dog.rb"]
  end

  def test_clear
    mock_file_hash
    @store.save_report(basic_coverage)
    @store.clear!
    assert_equal({}, @store.coverage)
  end

  def test_clear_file
    mock_file_hash
    @store.save_report(basic_coverage)
    @store.clear_file!("app_path/dog.rb")
    assert_nil @store.get_coverage_report[:merged]["app_path/dog.rb"]
  end

  def test_size_reports_bytes_or_nil
    mock_file_hash
    assert_nil @store.size
    assert_equal "N/A", @store.size_in_mib
    @store.save_report(basic_coverage)
    assert @store.size > 1
    refute_equal "N/A", @store.size_in_mib
  end

  def test_file_count
    mock_file_hash
    @store.save_report(basic_coverage)
    assert_equal 1, @store.file_count
  end

  def test_capabilities
    assert @store.persistent_coverage?
    assert @store.supports_trackers?
    refute @store.supports_paged_reports?
  end

  def test_raw_store_is_not_supported
    assert_raises(NotImplementedError) { @store.raw_store }
  end

  ###
  # Coverage counts are additive, so a lost update can't be repaired by writing
  # again. Two adapters over the same cache have to converge exactly.
  ###
  def test_concurrent_writers_converge_without_double_counting
    mock_file_hash
    other = build_store

    @store.save_report("app_path/dog.rb" => [1, 0, 0])
    other.save_report("app_path/dog.rb" => [0, 1, 0])
    3.times do
      @store.save_report({})
      other.save_report({})
    end

    assert_equal [1, 1, 0], @store.coverage["app_path/dog.rb"]["data"]
  end
end

class ActiveSupportMemoryCacheStoreTest < Minitest::Test
  include ActiveSupportCacheStoreBehavior

  def setup
    super
    @cache = ActiveSupport::Cache::MemoryStore.new
    @store = build_store
  end

  attr_reader :cache

  ###
  # Rails.cache does not exist while config/coverband.rb is loading, so the
  # target has to be resolvable later, and resolved exactly once.
  ###
  def test_lazy_target_is_resolved_once
    calls = 0
    store = Coverband::Adapters::ActiveSupportCacheStore.new do
      calls += 1
      @cache
    end
    mock_file_hash
    store.save_report(basic_coverage)
    store.coverage
    assert_equal 1, calls
  end

  def test_lazy_target_resolves_once_under_concurrent_first_access
    calls = 0
    mutex = Mutex.new
    store = Coverband::Adapters::ActiveSupportCacheStore.new do
      mutex.synchronize { calls += 1 }
      @cache
    end
    threads = 4.times.map { Thread.new { store.send(:instance_variable_get, :@target).target } }
    threads.each(&:join)
    assert_equal 1, calls
  end
end

class ActiveSupportFileCacheStoreTest < Minitest::Test
  include ActiveSupportCacheStoreBehavior

  def setup
    super
    @dir = File.join(Dir.tmpdir, "coverband_cache_test_#{Process.pid}_#{rand(10_000)}")
    @cache = ActiveSupport::Cache::FileStore.new(@dir)
    @store = build_store
  end

  def teardown
    FileUtils.rm_rf(@dir)
    super
  end

  attr_reader :cache
end

if ENV["COVERBAND_MEMCACHED"]
  require "dalli"

  class ActiveSupportMemcachedStoreTest < Minitest::Test
    include ActiveSupportCacheStoreBehavior

    def setup
      super
      @cache = ActiveSupport::Cache::MemCacheStore.new(ENV["MEMCACHED_URL"] || "localhost:11211")
      @cache.clear
      @store = build_store
    end

    attr_reader :cache

    ###
    # Memcached's default 1MB cap applies to every document, trackers included.
    # A refused write must keep the work pending rather than dropping it, and
    # must say something a human can act on.
    ###
    def test_oversized_document_retains_pending_and_warns
      messages = []
      logger = Object.new
      logger.define_singleton_method(:info) { |message| messages << message }
      logger.define_singleton_method(:error) { |message| messages << message }
      Coverband.configuration.stubs(:logger).returns(logger)

      store = build_store
      session = store.send(:session_for, Coverband::RUNTIME_TYPE)
      # past the 1MB slab limit even after the store compresses it, which is
      # what a large translation tracker looks like on a real app
      oversized = 40.times.each_with_object({}) do |i, hash|
        hash["key_#{i}"] = SecureRandom.hex(32_768)
      end
      session.enqueue(oversized)
      assert_equal :failed, session.flush
      assert_equal 1, session.pending_size, "a refused write must keep the work, not drop it"
      assert messages.any? { |message| message.include?("failed to write") },
        "the warning has to name what could not be stored"
    end

    ###
    # The cap applies to trackers too, not just the coverage blob.
    ###
    def test_tracker_documents_share_the_same_size_limit
      factory = build_store.tracker_storage
      repo = factory.for("Oversized", merger: ->(doc, delta) { doc.payload.merge!(delta.payload) })
      assert_equal :written_unconfirmed, repo.record({"small" => "1"})
    end
  end
end

###
# Deprecated, but existing configuration has to keep working: the namespace
# option and its reader survive even though the storage format did not.
###
class MemcachedStoreCompatibilityTest < Minitest::Test
  def test_namespace_option_is_translated
    cache = ActiveSupport::Cache::MemoryStore.new
    store = Coverband::Adapters::MemcachedStore.new(cache, memcached_namespace: "legacy_ns")
    assert_equal "legacy_ns", store.memcached_namespace
    assert_equal "legacy_ns", store.cache_namespace
    assert_equal cache, store.memcached
    assert_kind_of Coverband::Adapters::ActiveSupportCacheStore, store
  end
end
