# frozen_string_literal: true

require "time"

module Coverband
  # Normalizes the storage protocol diagnostics exposed by coverage stores and
  # trackers. These values describe state Coverband has already observed; they
  # do not probe the backend or promise that it is currently reachable.
  module StorageHealth
    module_function

    def report(configuration: Coverband.configuration, coverage: configuration.store)
      {
        coverage: for_source(coverage),
        trackers: tracker_health(configuration)
      }
    end

    def for_source(source)
      return unsupported unless diagnostics_supported?(source)

      loss = source.data_loss
      held = source.unwritten

      {
        status: status(loss, held),
        data_loss: normalize_data_loss(loss),
        unwritten: normalize_unwritten(held)
      }
    rescue
      unsupported
    end

    def tracker_health(configuration)
      Coverband::Collectors::TrackerRegistry.names.each_with_object({}) do |name, health|
        tracker = configuration.tracker_for(name)
        health[name] = for_source(tracker) if tracker
      end
    end
    private_class_method :tracker_health

    def diagnostics_supported?(source)
      source&.respond_to?(:data_loss) && source.respond_to?(:unwritten)
    end
    private_class_method :diagnostics_supported?

    def status(loss, held)
      return "data_loss" if loss
      return "stalled" if held

      "ok"
    end
    private_class_method :status

    def normalize_data_loss(loss)
      return unless loss

      {
        kind: loss.kind.to_s,
        at: format_time(loss.at),
        detail: loss.detail
      }
    end
    private_class_method :normalize_data_loss

    def normalize_unwritten(held)
      return unless held

      {
        deltas: held.deltas,
        since: format_time(held.since)
      }
    end
    private_class_method :normalize_unwritten

    def format_time(value)
      value.respond_to?(:iso8601) ? value.iso8601 : value&.to_s
    end
    private_class_method :format_time

    def unsupported
      {
        status: "unsupported",
        data_loss: nil,
        unwritten: nil
      }
    end
    private_class_method :unsupported
  end
end
