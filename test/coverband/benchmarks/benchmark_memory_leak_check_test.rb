# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "rake"

load File.expand_path("../../benchmarks/benchmark.rake", File.dirname(__FILE__)) unless respond_to?(:assert_no_coverband_leak, true)

class BenchmarkMemoryLeakCheckTest < Minitest::Test
  def test_raises_when_coverband_retains_objects
    data = <<~REPORT
      retained objects by gem
      -----------------------------------
               1  coverband

      retained objects by file
      -----------------------------------
    REPORT

    error = assert_raises(RuntimeError) { send(:assert_no_coverband_leak, data) }
    assert_equal "leaking memory!!!", error.message
  end

  # Regression test for https://github.com/danmayer/coverband/pull/647 CI failures:
  # newer Ruby/json versions retain a small internal string-dedup cache that is not
  # a Coverband leak, so it must not trip the check.
  def test_does_not_raise_when_only_external_gems_retain_memory
    data = <<~REPORT
      retained objects by gem
      -----------------------------------
               7  json-2.21.2
               1  redis-client-0.30.1

      retained objects by file
      -----------------------------------
    REPORT

    send(:assert_no_coverband_leak, data)
  end

  def test_does_not_raise_when_nothing_retained
    send(:assert_no_coverband_leak, "Total retained:  0 bytes (0 objects)\n")
  end
end
