# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))
require File.expand_path('./dog', File.dirname(__FILE__))

class CollectorsBaseTest < Test::Unit::TestCase
  def setup
    Coverband.configure do |config|
    end
  end

  test 'defaults to a redis store' do
    coverband = Coverband::Collectors::Base.instance.reset_instance
    assert_equal Coverband::Adapters::RedisStore, coverband.instance_variable_get('@store').class
  end

end
