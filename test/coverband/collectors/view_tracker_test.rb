require File.expand_path('../../test_helper', File.dirname(__FILE__))

class ReporterTest < Minitest::Test

  def setup
    super
    fake_store.raw_store.del('render_tracker')
  end

  test "init correctly" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    tracker = Coverband::Collectors::ViewTracker.new(:store => "store", :roots => 'dir')
    assert_equal 'dir', tracker.roots.first
    assert_equal 'store', tracker.store
    assert_equal [], tracker.target
    assert_equal [], tracker.logged_views
  end

  test "track partials" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    store.raw_store.expects(:sadd).with('render_tracker', file_path)
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: 'dir')
    tracker.track_views('name', 'start', 'finish', 'id', {:identifier => file_path})
    tracker.report_views_tracked
    assert_equal [file_path], tracker.logged_views
  end

  test "track layouts" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/layout"
    store.raw_store.expects(:sadd).with('render_tracker', file_path)
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: 'dir')
    tracker.track_views('name', 'start', 'finish', 'id', {:layout => file_path})
    tracker.report_views_tracked
    assert_equal [file_path], tracker.logged_views
  end

  test "report used partials" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: 'dir')
    tracker.track_views('name', 'start', 'finish', 'id', {:identifier => file_path})
    tracker.report_views_tracked
    assert_equal [file_path], tracker.used_views
  end

  test "report unused partials" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    file_path = "#{File.expand_path(Coverband.configuration.root)}/file"
    target = [file_path, 'not_used']
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: 'dir', target: target)
    tracker.track_views('name', 'start', 'finish', 'id', {:identifier => file_path})
    tracker.report_views_tracked
    assert_equal ['not_used'], tracker.unused_views
  end

  test "reset store" do
    Coverband::Collectors::ViewTracker.expects(:supported_version?).returns(true)
    store = fake_store
    store.raw_store.expects(:del).with('render_tracker')
    tracker = Coverband::Collectors::ViewTracker.new(store: store, roots: 'dir')
    tracker.track_views('name', 'start', 'finish', 'id', {:identifier => 'file'})
    tracker.reset_recordings
  end

  protected

  def fake_store
    @fake_store ||= Coverband::Adapters::RedisStore.new(Redis.new, redis_namespace: 'coverband_test')
  end

end
