# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class ViewTrackerTest < Minitest::Test
  def tracker_key
    "coverband_test_ViewTracker_tracker"
  end

  def setup
    super
    fake_store.raw_store.del(tracker_key)
  end

  test "init correctly" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    tracker = Coverband::Collectors::ViewTracker.new(store: fake_store, roots: "dir")
    assert_equal "dir", tracker.roots.first
    assert !tracker.store.nil?
    assert_equal [], tracker.target
    assert_equal [], tracker.logged_keys
  end

  test "track partials" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    store.raw_store.expects(:hset).with(tracker_key, file_path, anything)
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_key(identifier: file_path)
    tracker.save_report
    assert_equal [file_path], tracker.logged_keys
  end

  test "track partials that include the word vendor in the path" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/vendor_relations/file"
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_key(identifier: file_path)
    tracker.save_report
    assert_equal [file_path], tracker.used_keys.keys
  end

  test "track partials that include the word _mailer in the path" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/_mailer/file"
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_key(identifier: file_path)
    tracker.save_report
    assert_equal [file_path], tracker.used_keys.keys
  end

  test "ignore partials that include the folder vendor in the path" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/vendor/file"
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_key(identifier: file_path)
    tracker.save_report
    assert_equal({}, tracker.used_keys)
  end

  test "track layouts" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/layout"
    store.raw_store.expects(:hset).with(tracker_key, file_path, anything)
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_key(layout: file_path)
    tracker.save_report
    assert_equal [file_path], tracker.logged_keys
  end

  test "report used partials" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_key(identifier: file_path)
    tracker.save_report
    assert_equal [file_path], tracker.used_keys.keys
  end

  test "report unused partials" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    target = [file_path, "not_used"]
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir", target: target)
    tracker.track_key(identifier: file_path)
    tracker.save_report
    assert_equal ["not_used"], tracker.unused_keys
  end

  test "reset store" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    store.raw_store.expects(:del).with(tracker_key)
    store.raw_store.expects(:del).with("#{tracker_key}_time")
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_key(identifier: "file")
    tracker.reset_recordings
  end

  test "clear_key" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    store.raw_store.expects(:hdel).with(tracker_key, file_path)
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_key(identifier: file_path)
    tracker.clear_key!("file")
    assert_equal [], tracker.logged_keys
  end

  protected

  def fake_store
    @fake_store ||= Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
  end
end
