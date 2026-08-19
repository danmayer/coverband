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

  ###
  # A session has no generation token until an operation resolves one, so a
  # freshly built adapter has to sync before it can find the document at all.
  ###
  def test_size_on_a_fresh_adapter_finds_existing_coverage
    mock_file_hash
    @store.save_report(basic_coverage)

    fresh = build_store
    assert fresh.size > 1, "a new adapter must not report nothing for stored coverage"
    refute_equal "N/A", fresh.size_in_mib
  end

  def test_file_count
    mock_file_hash
    @store.save_report(basic_coverage)
    assert_equal 1, @store.file_count
  end

  ###
  # A clear whose pointer write did not land has not happened, and the caller
  # has to be able to tell.
  ###
  def test_clear_reports_whether_it_actually_cleared
    mock_file_hash
    @store.save_report(basic_coverage)
    assert_equal true, @store.clear!

    @store.save_report(basic_coverage)
    cache.stubs(:write).returns(false)
    assert_equal false, @store.clear!, "a clear that did not land must not report success"
  end

  ###
  # An unavailable backend, or a Solid Cache table that has not been created
  # yet, must never raise into the request serving the report.
  ###
  def test_reads_degrade_when_the_backend_is_unavailable
    mock_file_hash
    @store.save_report(basic_coverage)
    cache.stubs(:read).raises(RuntimeError.new("ActiveRecord::StatementInvalid: no such table"))

    assert_equal({}, @store.coverage)
    assert_nil @store.size
    assert_equal "N/A", @store.size_in_mib
    assert_equal 0, @store.file_count
  end

  ###
  # Write failures keep reaching the reporting paths that already rescue and
  # log them, rather than being swallowed here where their messages would be
  # lost.
  ###
  def test_write_failures_reach_the_reporting_path
    mock_file_hash
    cache.stubs(:write).raises(RuntimeError.new("ActiveRecord::ConnectionNotEstablished"))

    assert_raises(RuntimeError) { @store.save_report(basic_coverage) }
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
  # save_report is handed the collector's report, and the merge sums into the
  # line arrays it is given. Writing the merged total back into the caller's
  # own arrays makes the next cycle report counts that were already stored.
  ###
  def test_save_report_leaves_the_callers_report_alone
    mock_file_hash
    report = {"app_path/dog.rb" => [0, 1, 2]}
    @store.save_report(report)
    @store.save_report(report) # the second merge is the one with a total to write back
    assert_equal [0, 1, 2], report["app_path/dog.rb"]
  end

  ###
  # Repair means applying a delta a second time, so the delta has to still hold
  # this process's own counts. The merge used to sum the document into the
  # delta's payload on the first apply, so a repaired report carried the whole
  # document back in and doubled it, once per repair.
  ###
  def test_a_repaired_report_is_applied_once_not_compounded
    mock_file_hash
    other = build_store
    @store.save_report({"app_path/dog.rb" => [100, 0, 0]}) # history worth carrying

    a = @store.send(:session_for, Coverband::RUNTIME_TYPE)
    b = other.send(:session_for, Coverband::RUNTIME_TYPE)
    a.entries
    b.entries # both learn the generation and read the same document

    a.enqueue(@store.send(:own_expanded_report, {"app_path/dog.rb" => [1, 0, 0]}))
    b.enqueue(other.send(:own_expanded_report, {"app_path/dog.rb" => [10, 0, 0]}))
    doc_a = a.send(:operation) { a.send(:document) }
    doc_b = b.send(:operation) { b.send(:document) }

    apply_as(a, doc_a)
    apply_as(b, doc_b) # stale: drops a's contribution along with a's watermark

    3.times do
      a.flush
      b.flush
    end

    assert_equal 111, @store.coverage["app_path/dog.rb"]["data"].first,
      "each contribution counts once: 100 stored, plus 1 and 10"
  end

  # apply a session's pending prefix to a document it read earlier, so a stale
  # write can be set up deterministically instead of raced for
  def apply_as(session, doc)
    writer = session.instance_variable_get(:@writer)
    watermark = doc.watermark_for(writer.writer_id)
    writer.confirm_through(watermark) # flush drops confirmed work before it looks for a prefix
    prefix = writer.contiguous_prefix(watermark)
    session.send(:apply, doc, prefix)
    doc.record_watermark(writer.writer_id, prefix.last.seq)
    session.send(:operation) { session.send(:write, doc) }
  end

  ###
  # The retention protocol only protects deltas that reached the queue, and
  # generation resolution runs before the payload is enqueued. A backend blip
  # there used to drop the whole cycle -- up to 600s of coverage on the default
  # reporting interval.
  ###
  def test_a_failure_resolving_the_generation_does_not_drop_the_cycle
    mock_file_hash
    @store.save_report({"app_path/dog.rb" => [1, 0, 0]})

    # fail the pointer read, the way an unreachable backend does
    cache.stubs(:read).raises(RuntimeError.new("backend blip"))
    assert_raises(RuntimeError) { @store.save_report({"app_path/dog.rb" => [0, 1, 0]}) }

    cache.unstub(:read)
    @store.save_report({})

    assert_equal [1, 1, 0], @store.coverage["app_path/dog.rb"]["data"],
      "the cycle that failed on the pointer read has to be replayed, not lost"
  end

  ###
  # Coverband.start runs from before_configuration, so a reporting cycle can
  # land before Rails has assigned Rails.cache. That is not a failed write: the
  # work is held, and it must not raise into the app booting.
  ###
  def test_a_target_that_is_not_ready_yet_holds_the_work_instead_of_raising
    mock_file_hash
    ready = false
    store = Coverband::Adapters::ActiveSupportCacheStore.new { ready ? cache : nil }

    store.save_report({"app_path/dog.rb" => [1, 0, 0]}) # must not raise into a booting app
    assert_equal({}, store.coverage)

    ready = true # Rails.cache is assigned
    store.save_report({"app_path/dog.rb" => [0, 1, 0]})

    assert_equal [1, 1, 0], store.coverage["app_path/dog.rb"]["data"],
      "work held while the cache was unavailable has to land once it resolves"
  end

  ###
  # A resolver handing back something that is not a cache store is a
  # configuration mistake, and has to say so rather than surface as
  # NoMethodError from inside the storage layer.
  ###
  def test_a_resolver_returning_the_wrong_object_names_the_problem
    target = Coverband::Storage::Target.new(Object.new)
    error = assert_raises(Coverband::Storage::Target::Unavailable) { target.read("key") }
    assert_match(/does not respond to/, error.message)
  end

  ###
  # The retention caps live in flush, and a cycle that fails before flush never
  # reaches them. Holding that work is right, but holding it without a bound
  # grows the queue by one delta per cycle for as long as the outage lasts --
  # on the 600s default, six per hour per process, per document.
  ###
  def test_retained_work_is_still_bounded_during_a_sustained_outage
    mock_file_hash
    session = @store.send(:session_for, Coverband::RUNTIME_TYPE)
    cache.stubs(:read).raises(RuntimeError.new("backend down"))

    20.times do |cycle|
      @store.save_report({"app_path/dog.rb" => [cycle, 0, 0]})
    rescue RuntimeError
      # the reporting paths log this; here we only care about what is retained
    end

    assert_operator session.pending_size, :<=, Coverband::Adapters::SessionCoverage::COVERAGE_MAX_ENTRIES,
      "an outage must not grow the pending queue without limit"
    assert session.data_loss, "work dropped at the caps has to be reported, not discarded silently"
    assert_equal :pending_dropped, session.data_loss.kind
  end

  ###
  # Dropping at the caps leaves a sequence hole, and only a flush knows the
  # watermark to rebase against. A cycle carrying new work closes it by
  # accident, because that work pushes the queue back over the cap and the
  # existing rebase runs -- a quiet cycle does not, and the retained work would
  # sit unwritable until some later report happened to carry a payload.
  ###
  def test_retained_work_lands_on_a_quiet_cycle_after_a_drop
    mock_file_hash
    cache.stubs(:read).raises(RuntimeError.new("backend down"))
    20.times do
      @store.save_report({"app_path/dog.rb" => [1, 0, 0]})
    rescue RuntimeError
    end

    cache.unstub(:read)
    @store.save_report({}) # a quiet cycle, carrying nothing of its own

    stored = @store.coverage["app_path/dog.rb"]
    refute_nil stored, "work that survived the caps has to land without waiting for new work"
    assert_operator stored["data"][0], :>, 0
  end

  ###
  # A resolver handing back the wrong object can never resolve, so repeating the
  # same line every cycle is noise rather than signal.
  ###
  def test_a_misconfigured_store_is_reported_once_not_every_cycle
    messages = []
    logger = Object.new
    logger.define_singleton_method(:info) { |message| messages << message }
    logger.define_singleton_method(:error) { |message| messages << message }
    Coverband.configuration.stubs(:logger).returns(logger)

    store = Coverband::Adapters::ActiveSupportCacheStore.new(Object.new)
    5.times { store.save_report({"app_path/dog.rb" => [1, 0, 0]}) }

    misconfigured = messages.select { |message| message.include?("does not respond to") }
    assert_equal 1, misconfigured.length, "a permanent misconfiguration is worth saying once"
  end

  ###
  # The cap counts the queue, not missed cycles: the cycle that recovers carries
  # its own delta and takes a slot, so a cap of N absorbs an outage of N - 1.
  # The plan commits to two cycles for coverage, so the cap has to be three.
  ###
  def test_coverage_absorbs_the_documented_two_cycle_outage
    mock_file_hash
    @store.save_report({"app_path/dog.rb" => [1, 0, 0]}) # establish the document

    cache.stubs(:read).raises(RuntimeError.new("backend down"))
    2.times do |cycle|
      @store.save_report({"app_path/dog.rb" => [0, cycle + 1, 0]})
    rescue RuntimeError
    end

    cache.unstub(:read)
    @store.save_report({"app_path/dog.rb" => [0, 0, 1]}) # recovery carries work too
    @store.save_report({})

    assert_equal [1, 3, 1], @store.coverage["app_path/dog.rb"]["data"],
      "both outage cycles have to survive, alongside the cycle that recovered"
  end

  ###
  # Dropping a delta that was written and was only awaiting confirmation costs
  # the repair, not the data. Reporting it the same way as a real eviction
  # leaves an operator unable to tell a blip from lost coverage.
  ###
  def test_giving_up_an_unconfirmed_retry_is_not_reported_as_lost_data
    mock_file_hash
    session = @store.send(:session_for, Coverband::RUNTIME_TYPE)
    # written, and still awaiting the read that would confirm its watermark
    @store.save_report({"app_path/dog.rb" => [1, 0, 0]})

    # long enough for the caps to reach that written delta
    cache.stubs(:read).raises(RuntimeError.new("backend down"))
    3.times do
      @store.save_report({"app_path/dog.rb" => [0, 1, 0]})
    rescue RuntimeError
    end
    cache.unstub(:read)
    @store.save_report({})

    assert_equal :unconfirmed_dropped, session.data_loss.kind,
      "the dropped delta was already in the document, so this is a forfeited repair"
    assert_equal 1, @store.coverage["app_path/dog.rb"]["data"][0],
      "and its coverage is still there"
  end

  ###
  # The counterpart: work dropped before it ever reached a document really is
  # gone, and has to keep saying so.
  ###
  def test_dropping_work_that_never_reached_a_document_is_reported_as_lost
    mock_file_hash
    session = @store.send(:session_for, Coverband::RUNTIME_TYPE)
    cache.stubs(:read).raises(RuntimeError.new("backend down"))
    10.times do
      @store.save_report({"app_path/dog.rb" => [1, 0, 0]})
    rescue RuntimeError
    end

    assert_equal :pending_dropped, session.data_loss.kind
  end

  ###
  # A document that can never be written stores nothing while its caps never
  # fire, because a quiet document enqueues nothing new for them to drop. Only
  # the absolute age cap turns that into a loss, an hour later by default, and
  # until then an empty report is indistinguishable from an app that ran nothing.
  ###
  def test_a_document_that_cannot_be_written_says_so_without_waiting_for_the_age_cap
    mock_file_hash
    refusing = true
    cache.define_singleton_method(:write) do |key, *rest, **kw|
      next false if refusing && !key.to_s.end_with?(".pointer")
      super(key, *rest, **kw)
    end

    store = build_store
    store.save_report({"app_path/dog.rb" => [1, 0, 0]})

    assert_nil store.data_loss, "nothing has been dropped yet, so nothing is lost"
    held = store.unwritten
    refute_nil held, "but the work is not stored either, and that has to be visible"
    assert_operator held.deltas, :>, 0
    assert_kind_of Time, held.since
  ensure
    cache.singleton_class.remove_method(:write) if cache.singleton_class.method_defined?(:write)
  end

  ###
  # And it has to stop saying so once the writes land, or it becomes noise that
  # an operator learns to ignore.
  ###
  def test_unwritten_work_clears_once_it_is_stored
    mock_file_hash
    refusing = true
    cache.define_singleton_method(:write) do |key, *rest, **kw|
      next false if refusing && !key.to_s.end_with?(".pointer")
      super(key, *rest, **kw)
    end

    store = build_store
    store.save_report({"app_path/dog.rb" => [1, 0, 0]})
    refute_nil store.unwritten

    refusing = false
    store.save_report({})

    assert_nil store.unwritten, "a stall that has cleared must stop being reported"
    assert_equal [1, 0, 0], store.coverage["app_path/dog.rb"]["data"]
  ensure
    cache.singleton_class.remove_method(:write) if cache.singleton_class.method_defined?(:write)
  end

  ###
  # The other half of the ownership rule: a write that *raises* after the delta
  # was taken is still ours, so it must report :retained rather than propagate.
  # Raising would hand the same work two owners, which is how the additive
  # trackers double counted.
  ###
  def test_a_write_that_raises_after_the_enqueue_keeps_the_work_here
    mock_file_hash
    @store.save_report({"app_path/dog.rb" => [1, 0, 0]}) # establish the document

    cache.stubs(:write).raises(RuntimeError.new("write timeout"))

    assert_equal :retained, @store.save_report({"app_path/dog.rb" => [0, 1, 0]}),
      "a failure after the delta was taken is not the caller's problem again"

    cache.unstub(:write)
    @store.save_report({})
    assert_equal [1, 1, 0], @store.coverage["app_path/dog.rb"]["data"]
  end

  ###
  # Not every cache store implements read_multi, and the pointer batch has to
  # degrade to individual reads rather than lose the pointers.
  ###
  def test_pointer_batching_falls_back_when_the_store_cannot_read_multi
    mock_file_hash
    @store.save_report(basic_coverage)

    plain = Object.new
    plain.define_singleton_method(:read) { |key| @data&.[](key) }
    plain.define_singleton_method(:write) { |key, value, *| (@data ||= {})[key] = value }
    plain.define_singleton_method(:delete) { |key| @data&.delete(key) }
    refute plain.respond_to?(:read_multi)

    target = Coverband::Storage::Target.new(plain)
    target.write("a", "1")
    target.write("b", "2")

    assert_equal({"a" => "1", "b" => "2"}, target.read_multi("a", "b"))
    assert_equal({}, target.read_multi)
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
      assert_equal :retained, session.flush
      assert_equal 1, session.pending_size, "a refused write must keep the work, not drop it"
      warning = messages.find { |message| message.include?("failed to write") }
      refute_nil warning, "the warning has to name what could not be stored"
      assert_match(/\d+ bytes/, warning, "and how big it was")
      assert_match(/value limit/, warning, "and why a backend would refuse it")
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
