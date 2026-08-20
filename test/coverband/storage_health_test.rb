# frozen_string_literal: true

require File.expand_path("../test_helper", File.dirname(__FILE__))

class StorageHealthTest < Minitest::Test
  DiagnosticSource = Struct.new(:data_loss, :unwritten)

  test "reports healthy diagnostics" do
    assert_equal({
      status: "ok",
      data_loss: nil,
      unwritten: nil
    }, Coverband::StorageHealth.for_source(DiagnosticSource.new))
  end

  test "reports stalled work with an ISO 8601 timestamp" do
    since = Time.utc(2026, 8, 19, 12, 1, 2)
    held = Coverband::Storage::Session::UnwrittenWork.new(deltas: 3, since: since)

    assert_equal({
      status: "stalled",
      data_loss: nil,
      unwritten: {deltas: 3, since: "2026-08-19T12:01:02Z"}
    }, Coverband::StorageHealth.for_source(DiagnosticSource.new(nil, held)))
  end

  test "reports data loss without losing its classification or detail" do
    at = Time.utc(2026, 8, 19, 12, 0, 1)
    loss = Coverband::Storage::Session::DataLoss.new(
      kind: :pending_dropped,
      at: at,
      detail: "dropped 2 pending deltas"
    )

    assert_equal({
      status: "data_loss",
      data_loss: {
        kind: "pending_dropped",
        at: "2026-08-19T12:00:01Z",
        detail: "dropped 2 pending deltas"
      },
      unwritten: nil
    }, Coverband::StorageHealth.for_source(DiagnosticSource.new(loss, nil)))
  end

  test "data loss takes precedence while retaining unwritten details" do
    loss = Coverband::Storage::Session::DataLoss.new(
      kind: :eviction,
      at: Time.utc(2026, 8, 19, 12),
      detail: "document disappeared"
    )
    held = Coverband::Storage::Session::UnwrittenWork.new(
      deltas: 1,
      since: Time.utc(2026, 8, 19, 12, 1)
    )

    health = Coverband::StorageHealth.for_source(DiagnosticSource.new(loss, held))

    assert_equal "data_loss", health[:status]
    assert_equal "eviction", health.dig(:data_loss, :kind)
    assert_equal 1, health.dig(:unwritten, :deltas)
  end

  test "sources without diagnostics are unsupported" do
    assert_equal({
      status: "unsupported",
      data_loss: nil,
      unwritten: nil
    }, Coverband::StorageHealth.for_source(Object.new))
  end

  test "diagnostic errors degrade to unsupported" do
    source = Object.new
    source.define_singleton_method(:data_loss) { raise "unavailable" }
    source.define_singleton_method(:unwritten) { nil }

    assert_equal "unsupported", Coverband::StorageHealth.for_source(source)[:status]
  end

  test "public report includes coverage and initialized trackers by registered name" do
    coverage = DiagnosticSource.new
    healthy_tracker = DiagnosticSource.new
    unsupported_tracker = Object.new
    configuration = Coverband.configuration

    configuration.stubs(:store).returns(coverage)
    Coverband::Collectors::TrackerRegistry.stubs(:names).returns([:custom_tracker, :legacy_tracker, :disabled_tracker])
    configuration.stubs(:tracker_for).with(:custom_tracker).returns(healthy_tracker)
    configuration.stubs(:tracker_for).with(:legacy_tracker).returns(unsupported_tracker)
    configuration.stubs(:tracker_for).with(:disabled_tracker).returns(nil)

    health = Coverband.storage_health

    assert_equal "ok", health.dig(:coverage, :status)
    assert_equal "ok", health.dig(:trackers, :custom_tracker, :status)
    assert_equal "unsupported", health.dig(:trackers, :legacy_tracker, :status)
    refute_includes health[:trackers], :disabled_tracker
  end
end
