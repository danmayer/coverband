# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class ViewTrackerTest < Minitest::Test
  def setup
    super
    Coverband.configuration.ignore += ["app/views/anything/ignore_me.html.erb"]
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
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_key(identifier: file_path)
    tracker.save_report
    assert_equal [file_path], tracker.logged_keys
    assert_equal [file_path], tracker.used_keys.keys
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
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_key(layout: file_path)
    tracker.save_report
    assert_equal [file_path], tracker.logged_keys
    assert_equal [file_path], tracker.used_keys.keys
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
    target = [file_path, "not_used.html.erb"]
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir", target: target)
    tracker.track_key(identifier: file_path)
    tracker.save_report
    assert_equal ["not_used.html.erb"], tracker.unused_keys
  end

  test "report hides partials marked in ignore config" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/app/views/anything/ignore_me.html.erb"
    target = [file_path, "not_used.html.erb"]
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir", target: target)
    tracker.track_key(identifier: file_path)
    tracker.save_report
    assert_equal ["not_used.html.erb"], tracker.unused_keys
    assert_equal [], tracker.used_keys.keys
  end

  test "track view_component renders via railtie" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/app/components/example_component.html.erb"
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    Coverband.configuration.expects(:view_tracker).returns(tracker).at_least_once
    tracker.railtie!

    ActiveSupport::Notifications.instrument("render.view_component", view_identifier: file_path)

    assert_includes tracker.logged_keys, file_path
  end

  test "reset store" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_key(identifier: file_path)
    tracker.save_report
    assert_equal [file_path], tracker.used_keys.keys

    assert tracker.reset_recordings
    assert_equal({}, tracker.used_keys)
    assert_equal "N/A", tracker.tracking_since
    assert_equal [], tracker.logged_keys
  end

  test "clear_key" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")
    tracker.track_key(identifier: file_path)
    tracker.save_report
    tracker.clear_key!("file")
    assert_equal [], tracker.logged_keys
    assert_equal [], tracker.used_keys.keys
  end

  test "no-op tracker operations with non-redis stores" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = Coverband::Adapters::NullStore.new
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: "dir")

    tracker.track_key(identifier: "file")
    tracker.save_report

    assert_equal({}, tracker.used_keys)
    assert_equal "N/A", tracker.tracking_since
    assert_nil tracker.reset_recordings
    assert_nil tracker.clear_key!("file")
    assert_nil tracker.data_loss
  end

  protected

  def fake_store
    @fake_store ||= Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
  end
end
