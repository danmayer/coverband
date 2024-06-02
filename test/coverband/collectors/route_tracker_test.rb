# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "ostruct"

class RouterTrackerTest < Minitest::Test
  # NOTE: using struct vs open struct as open struct has a special keyword method that overshadows the method value on Ruby 2.x
  Payload = Struct.new(:path, :method)

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
    assert_nil tracker.target.first
    assert !tracker.store.nil?
    assert_equal [], tracker.target
    assert_equal [], tracker.logged_keys
  end

  test "track redirect routes" do
    store = fake_store
    route_hash = {controller: nil, action: nil, url_path: "path", verb: "GET"}
    store.raw_store.expects(:hset).with(tracker_key, route_hash.to_s, anything)
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")

    payload = {
      request: Payload.new("path", "GET"),
      status: 302,
      location: "https://coverband.dev/"
    }
    tracker.track_key(payload)
    tracker.save_report
    assert_equal [route_hash], tracker.logged_keys
  end

  test "track redirect routes when track_redirect_routes is false" do
    Coverband.configuration.track_redirect_routes = false

    store = fake_store
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")

    payload = {
      request: Payload.new("path", "GET"),
      status: 302,
      location: "https://coverband.dev/"
    }
    tracker.track_key(payload)
    tracker.save_report
    assert_equal [], tracker.logged_keys
  end

  test "track controller routes in Rails < 6.1" do
    store = fake_store
    route_hash = {controller: "some/controller", action: "index", url_path: nil, verb: "GET"}
    store.raw_store.expects(:hset).with(tracker_key, route_hash.to_s, anything)
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")
    payload = {
      params: {"controller" => "some/controller"},
      controller: "SomeController",
      action: "index",
      path: "path",
      method: "GET"
    }
    tracker.track_key(payload)
    tracker.save_report
    assert_equal [route_hash], tracker.logged_keys
  end

  test "track controller routes in Rails >= 6.1" do
    store = fake_store
    route_hash = {controller: "some/controller", action: "index", url_path: nil, verb: "GET"}
    store.raw_store.expects(:hset).with(tracker_key, route_hash.to_s, anything)
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")
    payload = {
      params: {
        "controller" => "some/controller",
        "action" => "index"
      },
      controller: "SomeController",
      action: "index",
      path: "path",
      method: "GET",
      request: Payload.new("path", "GET")
    }
    tracker.track_key(payload)
    tracker.save_report
    assert_equal [route_hash], tracker.logged_keys
  end

  test "report used routes" do
    store = fake_store
    route_hash = {controller: "some/controller", action: "index", url_path: nil, verb: "GET"}
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")
    payload = {
      params: {"controller" => "some/controller"},
      controller: "SomeController",
      action: "index",
      path: "path",
      method: "GET"
    }
    tracker.track_key(payload)
    tracker.save_report
    assert_equal [route_hash.to_s], tracker.used_keys.keys
  end

  test "report unused routes" do
    store = fake_store
    app_routes = [
      {
        controller: "some/controller",
        action: "show",
        url_path: "some/controller/show",
        verb: "GET"
      },
      {
        controller: "some/controller",
        action: "index",
        url_path: "some/controller/show",
        verb: "GET"
      }
    ]
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir", target: app_routes)
    payload = {
      params: {"controller" => "some/controller"},
      controller: "SomeController",
      action: "index",
      path: "path",
      method: "GET"
    }
    tracker.track_key(payload)
    tracker.save_report
    assert_equal [app_routes.first], tracker.unused_keys
  end

  test "report unused routes pulls out parameterized routes" do
    store = fake_store
    app_routes = [
      {
        controller: "some/controller",
        action: "show",
        url_path: "some/controller/:user_id",
        verb: "GET"
      }
    ]
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir", target: app_routes)
    payload = {
      params: {"controller" => "some/controller"},
      controller: "SomeController",
      action: "show",
      path: "some/controller/123",
      method: "GET"
    }
    tracker.track_key(payload)
    tracker.save_report
    assert_equal [], tracker.unused_keys
  end

  test "reset store" do
    store = fake_store
    payload = {
      params: {"controller" => "some/controller"},
      controller: "SomeController",
      action: "index",
      path: "path",
      method: "GET"
    }
    store.raw_store.expects(:del).with(tracker_key)
    store.raw_store.expects(:del).with("#{tracker_key}_time")
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")
    tracker.track_key(payload)
    tracker.reset_recordings
  end

  test "clear_file" do
    store = fake_store
    route_hash = {controller: "some/controller", action: "index", url_path: nil, verb: "GET"}
    tracker = Coverband::Collectors::RouteTracker.new(store: store, roots: "dir")
    payload = {
      params: {"controller" => "some/controller"},
      controller: "SomeController",
      action: "index",
      path: "path",
      method: "GET"
    }
    tracker.track_key(payload)
    tracker.save_report
    assert_equal [route_hash.to_s], tracker.used_keys.keys
    tracker.clear_key!(route_hash.to_s)
    assert_equal [], tracker.store.raw_store.hgetall(tracker_key).keys
  end

  protected

  def fake_store
    @fake_store ||= Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
  end
end
