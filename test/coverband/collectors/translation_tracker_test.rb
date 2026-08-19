# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class TranslationTrackerTest < Minitest::Test
  # NOTE: using struct vs open struct as open struct has a special keyword method that overshadows the method value on Ruby 2.x
  Payload = Struct.new(:path, :method)

  def setup
    super
    Coverband::Collectors::TranslationTracker.stubs(:supported_version?).returns(true)
  end

  test "init correctly" do
    tracker = Coverband::Collectors::TranslationTracker.new(store: fake_store, roots: "dir")
    assert_nil tracker.target.first
    assert !tracker.store.nil?
    assert_equal [], tracker.target
    assert_equal [], tracker.logged_keys
  end

  test "track standard translation keys" do
    store = fake_store
    translation_key = "en.views.pagination.truncate"
    tracker = Coverband::Collectors::TranslationTracker.new(store: store, roots: "dir")

    tracker.track_key(translation_key.to_sym)
    tracker.save_report
    assert_equal [translation_key.to_sym], tracker.logged_keys
  end

  test "report used_keys" do
    store = fake_store
    translation_key = "en.views.pagination.truncate"
    tracker = Coverband::Collectors::TranslationTracker.new(store: store, roots: "dir")
    tracker.track_key(:"en.views.pagination.truncate")
    tracker.save_report
    assert_equal [translation_key], tracker.used_keys.keys
  end

  test "report unused_keys" do
    store = fake_store
    app_keys = [
      "en.views.pagination.truncate",
      "en.views.pagination.next"
    ]
    tracker = Coverband::Collectors::TranslationTracker.new(store: store, roots: "dir", target: app_keys)
    tracker.track_key(:"en.views.pagination.truncate")
    tracker.save_report
    assert_equal [app_keys.last], tracker.unused_keys
  end

  test "reset store" do
    store = fake_store
    tracker = Coverband::Collectors::TranslationTracker.new(store: store, roots: "dir")
    tracker.track_key(:"en.views.pagination.truncate")
    tracker.reset_recordings
  end

  test "clear_key" do
    store = fake_store
    translation_key = "en.views.pagination.truncate"
    tracker = Coverband::Collectors::TranslationTracker.new(store: store, roots: "dir")
    tracker.track_key(translation_key.to_sym)
    tracker.save_report
    assert_equal [translation_key.to_s], tracker.used_keys.keys
    tracker.clear_key!(translation_key.to_s)
    assert_equal [], tracker.used_keys.keys
  end

  protected

  ###
  # Work dropped at the storage caps is gone, and the dedupe set has already
  # moved on, so those keys would never be reported again -- a used translation
  # reading as unused, which is the dangerous direction for anything driving
  # deletion. Presence merging is idempotent, so re-supplying costs nothing.
  ###
  test "keys dropped at the storage caps come back on an idempotent tracker" do
    require "active_support"
    require "active_support/cache"

    refusing = false
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.define_singleton_method(:write) do |key, *rest, **kw|
      next false if refusing && !key.to_s.end_with?(".pointer")
      super(key, *rest, **kw)
    end
    store = Coverband::Adapters::ActiveSupportCacheStore.new(cache, cache_namespace: "translation_drop")
    tracker = Coverband::Collectors::TranslationTracker.new(store: store, roots: "dir")

    # far past the storage queue's cap, so the earliest deltas are dropped
    refusing = true
    12.times do |i|
      tracker.track_key(:"en.a.k_#{i}")
      tracker.save_report
    end

    refusing = false
    tracker.save_report
    tracker.save_report

    expected = 12.times.map { |i| "en.a.k_#{i}" }
    assert_equal [], expected - tracker.used_keys.keys,
      "a key this process still knows about must not be lost to a capped queue"
  end

  ###
  # The counterpart: re-supplying a summed counter is the double count the
  # retained state exists to prevent, so an additive tracker keeps its loss.
  ###
  test "an additive tracker does not resupply dropped work" do
    Coverband::Collectors::TranslationTracker.new(store: fake_store, roots: "dir")
    assert Coverband::Collectors::TranslationTracker.idempotent_merge?
    refute Coverband::Collectors::QueryBurstTracker.idempotent_merge?
  end

  def fake_store
    @fake_store ||= Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
  end
end
