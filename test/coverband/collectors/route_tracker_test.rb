# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "ostruct"

class RouterTrackerTest < Minitest::Test
  def tracker_key
    Coverband::Collectors::RouteTracker.expects(:supported_version?).at_least_once.returns(true)
    Coverband::Collectors::RouteTracker.new.send(:tracker_key)
  end

  def setup
    super
    fake_store.raw_store.del(tracker_key)
  end

  test "init correctly" do
    Coverband::Collectors::RouteTracker.expects(:supported_version?).returns(true)
    tracker = Coverband::Collectors::RouteTracker.new(store: fake_store, roots: "dir")
    assert_equal nil, tracker.target.first
    assert !tracker.store.nil?
    assert_equal [], tracker.target
    assert_equal [], tracker.logged_routes
  end

  test "track redirect routes" do
    store = fake_store
    route_hash = {controller: nil, action: nil, url_path: "path", verb: "GET"}
    store.raw_store.expects(:hset).with(tracker_key, route_hash.to_s, anything)
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")
    payload = {
      request: OpenStruct.new(
        path: "path",
        method: "GET"
      )
    }
    tracker.track_routes("name", "start", "finish", "id", payload)
    tracker.report_routes_tracked
    assert_equal [route_hash], tracker.logged_routes
  end

  test "track controller routes" do
    store = fake_store
    route_hash = {controller: "SomeController", action: "index", url_path: "path", verb: "GET"}
    store.raw_store.expects(:hset).with(tracker_key, route_hash.to_s, anything)
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")
    payload = {
      controller: "SomeController",
      action: "index",
      path: "path",
      method: "GET"
    }
    tracker.track_routes("name", "start", "finish", "id", payload)
    tracker.report_routes_tracked
    assert_equal [route_hash], tracker.logged_routes
  end

  test "report used routes" do
    store = fake_store
    route_hash = {controller: "SomeController", action: "index", url_path: "path", verb: "GET"}
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")
    payload = {
      controller: "SomeController",
      action: "index",
      path: "path",
      method: "GET"
    }
    tracker.track_routes("name", "start", "finish", "id", payload)
    tracker.report_routes_tracked
    assert_equal [route_hash.to_s], tracker.used_routes.keys
  end

  test "report unused routes" do
    store = fake_store
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")
    payload = {
      controller: "SomeController",
      action: "index",
      path: "path",
      method: "GET"
    }
    tracker.track_routes("name", "start", "finish", "id", payload)
    tracker.report_routes_tracked
    assert_equal [], tracker.unused_routes
  end

  test "reset store" do
    store = fake_store
    payload = {
      controller: "SomeController",
      action: "index",
      path: "path",
      method: "GET"
    }
    store.raw_store.expects(:del).with(tracker_key)
    store.raw_store.expects(:del).with("route_tracker_time")
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")
    tracker.track_routes("name", "start", "finish", "id", payload)
    tracker.reset_recordings
  end

  test "clear_file" do
    store = fake_store
    route_hash = {controller: "SomeController", action: "index", url_path: "path", verb: "GET"}
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")
    payload = {
      controller: "SomeController",
      action: "index",
      path: "path",
      method: "GET"
    }
    tracker.track_routes("name", "start", "finish", "id", payload)
    tracker.report_routes_tracked
    assert_equal [route_hash.to_s], tracker.used_routes.keys
    tracker.clear_route!(route_hash.to_s)
    assert_equal [], tracker.store.raw_store.hgetall(tracker_key).keys
  end

  protected

  def fake_store
    @fake_store ||= Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
  end
end
