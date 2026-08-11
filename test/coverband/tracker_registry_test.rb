# frozen_string_literal: true

require File.expand_path("../test_helper", File.dirname(__FILE__))

class TrackerRegistryTest < Minitest::Test
  def setup
    super
    @registered_entries = Coverband::Collectors::TrackerRegistry.registry.values.dup
    @dynamic_flag_defaults = Coverband::Configuration.dynamic_flag_defaults.dup
  end

  def teardown
    Coverband::Collectors::TrackerRegistry.reset!
    @registered_entries.each do |entry|
      Coverband::Collectors::TrackerRegistry.register(
        entry.name,
        tracker_class: entry.tracker_class,
        enabled: entry.enabled_proc
      )
    end
    Coverband::Configuration.instance_variable_set(:@dynamic_flag_defaults, @dynamic_flag_defaults)
    super
  end

  test "bundled trackers register themselves" do
    assert_equal(
      [:view_tracker, :route_tracker, :translations_tracker, :query_burst_tracker],
      Coverband::Collectors::TrackerRegistry.names
    )
  end

  test "register stores tracker metadata by symbolic name" do
    tracker_class = Class.new
    enabled = ->(config) { config.enabled }

    Coverband::Collectors::TrackerRegistry.register(
      "custom_tracker",
      tracker_class: tracker_class,
      enabled: enabled
    )

    entry = Coverband::Collectors::TrackerRegistry.registry.fetch(:custom_tracker)
    assert_equal :custom_tracker, entry.name
    assert_same tracker_class, entry.tracker_class
    assert_same enabled, entry.enabled_proc
    assert_equal :custom_tracker, entry.accessor_name
  end

  test "duplicate registration raises an argument error" do
    Coverband::Collectors::TrackerRegistry.register(:custom_tracker, tracker_class: Class.new, enabled: ->(_config) { true })

    error = assert_raises(ArgumentError) do
      Coverband::Collectors::TrackerRegistry.register(:custom_tracker, tracker_class: Class.new, enabled: ->(_config) { true })
    end

    assert_equal "Tracker already registered: custom_tracker", error.message
  end

  test "each yields entries in registration order and names returns their names" do
    Coverband::Collectors::TrackerRegistry.reset!
    Coverband::Collectors::TrackerRegistry.register(:first, tracker_class: Class.new, enabled: ->(_config) { true })
    Coverband::Collectors::TrackerRegistry.register(:second, tracker_class: Class.new, enabled: ->(_config) { true })

    assert_equal [:first, :second], Coverband::Collectors::TrackerRegistry.names
    assert_equal [:first, :second], Coverband::Collectors::TrackerRegistry.each.map(&:name)
  end

  test "reset clears registrations" do
    Coverband::Collectors::TrackerRegistry.reset!

    assert_empty Coverband::Collectors::TrackerRegistry.names
  end

  test "registered external tracker is initialized through the public API" do
    tracker_class = Class.new do
      attr_reader :initialized

      def railtie!
        @initialized = true
      end
    end
    Coverband::Configuration.add_tracker_flag(:track_custom, default: false)
    Coverband::Collectors::TrackerRegistry.register(
      :custom_tracker,
      tracker_class: tracker_class,
      enabled: ->(config) { config.track_custom }
    )

    config = Coverband::Configuration.new
    config.track_views = false
    config.track_custom = true
    config.railtie!

    tracker = config.trackers.fetch(0)
    assert_instance_of tracker_class, tracker
    assert tracker.initialized
  end

  test "dynamic tracker flags apply their default when configuration resets" do
    Coverband::Configuration.add_tracker_flag(:track_default_on, default: true)
    config = Coverband::Configuration.new
    config.track_default_on = false

    config.reset

    assert_equal true, config.track_default_on
  end
end
