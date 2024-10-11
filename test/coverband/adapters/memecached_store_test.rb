# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

if ENV["COVERBAND_MEMCACHED"]
  require "active_support"
  require "dalli"

  class MemcachedTest < Minitest::Test
    def setup
      super
      @store = Coverband::Adapters::MemcachedStore.new(ActiveSupport::Cache::MemCacheStore.new)
    end

    def test_coverage
      @store.clear!
      mock_file_hash
      expected = basic_coverage
      @store.save_report(expected)
      assert_equal expected.keys, @store.coverage.keys
      @store.coverage.each_pair do |key, data|
        assert_equal expected[key], data["data"]
      end
    end
  end
end
