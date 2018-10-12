# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class BaseTest < Test::Unit::TestCase
  test 'defaults ' do
    assert_equal 'coverage', Coverband.configuration.collector
    coverband = Coverband::Collectors::Base.instance.reset_instance
    assert_equal 'coverage', Coverband.configuration.collector
    assert_equal ['vendor', 'internal:prelude', 'schema.rb',], coverband.instance_variable_get('@ignore_patterns')
  end
end
