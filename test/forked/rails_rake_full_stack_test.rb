# frozen_string_literal: true

require File.expand_path("../rails_test_helper", File.dirname(__FILE__))
require "rails"

class RailsRakeFullStackTest < Minitest::Test
  def setup
    super
    Coverband.configuration.reset
    Coverband.configure("./test/rails#{Rails::VERSION::MAJOR}_dummy/config/coverband.rb")
  end

  # test 'rake tasks shows coverage properly within eager_loading' do
  # this was testing gem data, which we no longer support and I dont know if this makes sense anymre
  # end

  test "ignored rake tasks don't add coverage" do
    store.clear!
    store.instance_variable_set(:@redis_namespace, "coverband_test")
    store.send(:save_report, basic_coverage_full_path)
    output = `COVERBAND_CONFIG=./test/rails#{Rails::VERSION::MAJOR}_dummy/config/coverband.rb bundle exec rake -f test/rails#{Rails::VERSION::MAJOR}_dummy/Rakefile coverband:clear`
    assert_nil output.match(/Coverband: Reported coverage via thread/)
    coverage_report = store.get_coverage_report
    empty_hash = {}
    assert_equal empty_hash, coverage_report[Coverband::RUNTIME_TYPE]
    assert_equal empty_hash, coverage_report[:eager_loading]
    assert_equal empty_hash, coverage_report[:merged]
  end

  test "doesn't exit non-zero with error on missing redis" do
    output = `COVERBAND_CONFIG=./test/rails#{Rails::VERSION::MAJOR}_dummy/config/coverband_missing_redis.rb bundle exec rake -f test/rails#{Rails::VERSION::MAJOR}_dummy/Rakefile -T`
    assert_equal 0, $?.to_i
    if ENV["COVERBAND_HASH_REDIS_STORE"]
      assert output.match(/Redis is not available/)
    else
      assert output.match(/coverage failed to store/)
    end
  end
end
