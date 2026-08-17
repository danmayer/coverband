# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class TrackerRegistryTest < Minitest::Test
  BUNDLED_TRACKERS = [:view_tracker, :route_tracker, :translations_tracker, :query_burst_tracker]

  # a tracker written the way the README documents one
  class FakeFeatureFlagTracker < Coverband::Collectors::AbstractTracker
    REPORT_ROUTE = "feature_flag_tracker"
    TITLE = "Feature Flags"

    def self.supported_version?
      true
    end

    def railtie!
      @railtied = true
    end

    def railtied?
      @railtied == true
    end

    private

    def concrete_target
      ["flags.new_checkout"]
    end
  end

  # a tracker that forgets to declare where it reports
  class RoutelessTracker < Coverband::Collectors::AbstractTracker
    def self.supported_version?
      true
    end

    private

    def concrete_target
      []
    end
  end

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
    remove_added_tracker_flags
    Coverband::Configuration.instance_variable_set(:@dynamic_flag_defaults, @dynamic_flag_defaults)
    super
  end

  test "bundled trackers register themselves" do
    names = Coverband::Collectors::TrackerRegistry.names

    BUNDLED_TRACKERS.each { |name| assert_includes names, name }
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
  end

  test "duplicate registration raises an argument error" do
    Coverband::Collectors::TrackerRegistry.register(:custom_tracker, tracker_class: Class.new, enabled: ->(_config) { true })

    error = assert_raises(ArgumentError) do
      Coverband::Collectors::TrackerRegistry.register(:custom_tracker, tracker_class: Class.new, enabled: ->(_config) { true })
    end

    assert_equal "Tracker already registered: custom_tracker", error.message
  end

  test "registering a tracker without its own REPORT_ROUTE raises an argument error" do
    error = assert_raises(ArgumentError) do
      Coverband::Collectors::TrackerRegistry.register(
        :routeless_tracker,
        tracker_class: RoutelessTracker,
        enabled: ->(_config) { true }
      )
    end

    assert_match "must define its own REPORT_ROUTE", error.message
    refute_includes Coverband::Collectors::TrackerRegistry.names, :routeless_tracker
  end

  test "a callable building a tracker without its own REPORT_ROUTE raises at boot" do
    Coverband::Configuration.add_tracker_flag(:track_routeless, default: false)
    Coverband::Collectors::TrackerRegistry.reset!
    Coverband::Collectors::TrackerRegistry.register(
      :routeless_tracker,
      tracker_class: -> { RoutelessTracker.new },
      enabled: ->(config) { config.track_routeless }
    )

    config = Coverband::Configuration.new
    config.track_routeless = true

    error = assert_raises(ArgumentError) { config.railtie! }
    assert_match "must define its own REPORT_ROUTE", error.message
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

  test "the documented custom tracker workflow boots, reports on its own route, and tracks keys" do
    Coverband::Configuration.add_tracker_flag(:track_feature_flags, default: false)
    Coverband::Collectors::TrackerRegistry.reset!
    Coverband::Collectors::TrackerRegistry.register(
      :feature_flag_tracker,
      tracker_class: FakeFeatureFlagTracker,
      enabled: ->(config) { config.track_feature_flags }
    )

    config = Coverband::Configuration.new
    config.track_feature_flags = true
    config.railtie!

    tracker = config.trackers.fetch(0)
    assert_instance_of FakeFeatureFlagTracker, tracker
    assert tracker.railtied?

    # the tracker only claims its own path in the web report
    assert_equal "feature_flag_tracker", tracker.route
    assert_equal "Feature Flags", tracker.title
    refute_match tracker.class::REPORT_ROUTE, "/view_tracker"

    # a tracker with no dedicated accessor is still reachable by name
    assert_same tracker, config.tracker_for(:feature_flag_tracker)

    Coverband.stubs(:configuration).returns(config)
    assert Coverband.track_key(:feature_flag_tracker, "flags.new_checkout")
    assert_includes tracker.logged_keys, "flags.new_checkout"
  end

  test "dynamic tracker flags apply their default when configuration resets" do
    Coverband::Configuration.add_tracker_flag(:track_default_on, default: true)
    config = Coverband::Configuration.new
    config.track_default_on = false

    config.reset

    assert_equal true, config.track_default_on
  end

  private

  # add_tracker_flag defines accessors on Configuration itself, without this
  # they leak into every test that runs after these
  def remove_added_tracker_flags
    added = Coverband::Configuration.dynamic_flag_defaults.keys - @dynamic_flag_defaults.keys
    added.each do |name|
      [name, :"#{name}="].each do |method_name|
        Coverband::Configuration.send(:remove_method, method_name) if Coverband::Configuration.method_defined?(method_name)
      end
    end
  end
end
