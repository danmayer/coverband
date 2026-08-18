# frozen_string_literal: true

module Coverband
  module Collectors
    ###
    # Registry of the trackers Coverband initializes at Rails boot.
    #
    # Bundled trackers register themselves as their file is required. Apps and
    # gems register their own trackers the same way, which is all Coverband
    # needs to build them, hook them up, and report on them.
    ###
    class TrackerRegistry
      Entry = Struct.new(:name, :tracker_class, :enabled_proc, keyword_init: true)

      def self.registry
        @registry ||= {}
      end

      def self.register(name, tracker_class:, enabled:)
        name = name.to_sym
        raise ArgumentError, "Tracker already registered: #{name}" if registry.key?(name)

        # a callable can only be checked once it has built its tracker at boot
        validate_report_route!(name, tracker_class) unless tracker_class.respond_to?(:call)

        registry[name] = Entry.new(
          name: name,
          tracker_class: tracker_class,
          enabled_proc: enabled
        )
      end

      ###
      # A tracker that inherits AbstractTracker's default REPORT_ROUTE matches
      # every path in the web reporter, which hides the rest of the report.
      # Fail loudly rather than let a tracker take over the whole UI.
      ###
      def self.validate_report_route!(name, tracker_class)
        return unless tracker_class.is_a?(Class)
        return unless tracker_class < Coverband::Collectors::AbstractTracker

        default_route = Coverband::Collectors::AbstractTracker::REPORT_ROUTE
        return unless default_route == tracker_class::REPORT_ROUTE

        raise ArgumentError, "Tracker #{name} must define its own REPORT_ROUTE, " \
          "AbstractTracker's default #{default_route.inspect} matches every web report path"
      end

      def self.each(&block)
        registry.each_value(&block)
      end

      def self.names
        registry.keys
      end

      # intended for tests, resetting the registry of a booted app is not supported
      def self.reset!
        @registry = {}
      end
    end
  end
end
