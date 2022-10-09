# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class ViewTrackerTest < Minitest::Test
  def tracker_key
    "render_tracker_2"
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
    assert_equal [], tracker.logged_views
  end

  test "track partials" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    store.raw_store.expects(:hset).with(tracker_key, file_path, anything)
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_views("name", "start", "finish", "id", identifier: file_path)
    tracker.report_views_tracked
    assert_equal [file_path], tracker.logged_views
  end

  test "track partials that include the word vendor in the path" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/vendor_relations/file"
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_views("name", "start", "finish", "id", identifier: file_path)
    tracker.report_views_tracked
    assert_equal [file_path], tracker.used_views.keys
  end

  test "track partials that include the word _mailer in the path" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/_mailer/file"
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_views("name", "start", "finish", "id", identifier: file_path)
    tracker.report_views_tracked
    assert_equal [file_path], tracker.used_views.keys
  end

  test "ignore partials that include the folder vendor in the path" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/vendor/file"
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_views("name", "start", "finish", "id", identifier: file_path)
    tracker.report_views_tracked
    assert_equal({}, tracker.used_views)
  end

  test "track layouts" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/layout"
    store.raw_store.expects(:hset).with(tracker_key, file_path, anything)
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_views("name", "start", "finish", "id", layout: file_path)
    tracker.report_views_tracked
    assert_equal [file_path], tracker.logged_views
  end

  test "report used partials" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_views("name", "start", "finish", "id", identifier: file_path)
    tracker.report_views_tracked
    assert_equal [file_path], tracker.used_views.keys
  end

  test "report unused partials" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    target = [file_path, "not_used"]
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir", target: target)
    tracker.track_views("name", "start", "finish", "id", identifier: file_path)
    tracker.report_views_tracked
    assert_equal ["not_used"], tracker.unused_views
  end

  test "reset store" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    store.raw_store.expects(:del).with(tracker_key)
    store.raw_store.expects(:del).with("render_tracker_time")
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_views("name", "start", "finish", "id", identifier: "file")
    tracker.reset_recordings
  end

  test "clear_file" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    store.raw_store.expects(:hdel).with(tracker_key, file_path)
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_views("name", "start", "finish", "id", identifier: file_path)
    tracker.clear_file!("file")
    assert_equal [], tracker.logged_views
  end

  protected

  def fake_store
    @fake_store ||= Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
  end
end
