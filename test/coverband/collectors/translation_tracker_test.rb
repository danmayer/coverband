# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "ostruct"

class TranslationTrackerTest < Minitest::Test
  # NOTE: using struct vs open struct as open struct has a special keyword method that overshadows the method value on Ruby 2.x
  Payload = Struct.new(:path, :method)

  def tracker_key
    Coverband::Collectors::TranslationTracker.expects(:supported_version?).at_least_once.returns(true)
    Coverband::Collectors::TranslationTracker.new.send(:tracker_key)
  end

  def tracker_time_key
    Coverband::Collectors::TranslationTracker.expects(:supported_version?).at_least_once.returns(true)
    Coverband::Collectors::TranslationTracker.new.send(:tracker_time_key)
  end

  def setup
    super
    fake_store.raw_store.del(tracker_key)
  end

  test "init correctly" do
    Coverband::Collectors::TranslationTracker.expects(:supported_version?).returns(true)
    tracker = Coverband::Collectors::TranslationTracker.new(store: fake_store, roots: "dir")
    assert_equal nil, tracker.target.first
    assert !tracker.store.nil?
    assert_equal [], tracker.target
    assert_equal [], tracker.logged_keys
  end

  test "track standard translation keys" do
    store = fake_store
    translation_key = "en.views.pagination.truncate"
    store.raw_store.expects(:hset).with(tracker_key, translation_key, anything)
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
    store.raw_store.expects(:del).with(tracker_key)
    store.raw_store.expects(:del).with(tracker_time_key)
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
    assert_equal [], tracker.store.raw_store.hgetall(tracker_key).keys
  end

  protected

  def fake_store
    @fake_store ||= Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
  end
end
