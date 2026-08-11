# frozen_string_literal: true

module Coverband
  module Collectors
    class TrackerRegistry
      Entry = Struct.new(:name, :tracker_class, :enabled_proc, :accessor_name, keyword_init: true)

      class << self
        def registry
          @registry ||= {}
        end

        def register(name, tracker_class:, enabled:)
          name = name.to_sym
          raise ArgumentError, "Tracker already registered: #{name}" if registry.key?(name)

          registry[name] = Entry.new(
            name: name,
            tracker_class: tracker_class,
            enabled_proc: enabled,
            accessor_name: name
          )
        end

        def each(&block)
          registry.each_value(&block)
        end

        def names
          registry.keys
        end

        def reset!
          @registry = {}
        end
      end
    end
  end
end
