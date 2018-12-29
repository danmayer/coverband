# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class BaseTest < Minitest::Test
  def setup
    super
    Coverband.configure do |config|
      config.root                = Dir.pwd
      config.s3_bucket           = nil
      config.root_paths          = ['/app_path/']
      config.ignore              = ['vendor']
      config.reporting_frequency = 100.0
      config.reporter            = 'std_out'
      config.store               = Coverband::Adapters::RedisStore.new(Redis.new)
    end
  end

  test 'defaults ' do
    coverband = Coverband::Collectors::Coverage.instance.reset_instance
    assert_equal ['vendor', 'internal:prelude', 'schema.rb'], coverband.instance_variable_get('@ignore_patterns')
  end
end
