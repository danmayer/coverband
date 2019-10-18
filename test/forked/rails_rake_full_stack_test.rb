# frozen_string_literal: true

require File.expand_path('../rails_test_helper', File.dirname(__FILE__))
require 'rails'
require 'pundit'

class RailsRakeFullStackTest < Minitest::Test
  def setup
    super
    Coverband.configuration.reset
    Coverband.configure("./test/rails#{Rails::VERSION::MAJOR}_dummy/config/coverband.rb")
  end

  test 'rake tasks shows coverage properly within eager_loading' do
    store.instance_variable_set(:@redis_namespace, 'coverband_test')
    store.clear!
    system("COVERBAND_CONFIG=./test/rails#{Rails::VERSION::MAJOR}_dummy/config/coverband.rb bundle exec rake -f test/rails#{Rails::VERSION::MAJOR}_dummy/Rakefile middleware")
    store.instance_variable_set(:@redis_namespace, 'coverband_test')
    store.type = :eager_loading
    pundit_file = store.coverage.keys.grep(/pundit.rb/).first
    refute_nil pundit_file
    pundit_coverage = store.coverage[pundit_file]
    refute_nil pundit_coverage
    assert_includes pundit_coverage['data'], 1

    store.type = Coverband::RUNTIME_TYPE
    if ENV['SIMULATE_ONESHOT']
      pundit_coverage = store.get_coverage_report[Coverband::RUNTIME_TYPE][pundit_file]
      assert pundit_coverage['data'].compact.all? { |el| el == 0 }
    else
      pundit_coverage = store.coverage[pundit_file]
      assert_nil pundit_coverage
    end
  end

  test "ignored rake tasks don't add coverage" do
    store.clear!
    store.instance_variable_set(:@redis_namespace, 'coverband_test')
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
    assert output.match(/coverage failed to store/)
  end
end
