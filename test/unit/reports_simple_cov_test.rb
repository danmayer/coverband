# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class ReportsSimpleCovTest < Test::Unit::TestCase
  BASE_KEY = Coverband::Adapters::RedisStore::BASE_KEY

  def setup
    @redis = Redis.new
    @redis.flushdb
    @store = Coverband::Adapters::RedisStore.new(@redis)
  end

  def example_hash
    {'1' => '1', '2' => '2'}
  end

  test 'generate scov report' do
    Coverband.configure do |config|
      config.redis             = @redis
      config.reporter          = 'scov'
      config.s3_bucket         = nil
      config.store             = @store
      config.ignore            = ['notsomething.rb']
    end
    Coverband.configuration.logger.stubs('info')

    @redis.sadd(BASE_KEY, 'test/unit/dog.rb')
    @store.send(:store_map, 'fakechecksum', "#{BASE_KEY}.test/unit/dog.rb", example_hash)

    SimpleCov.expects(:track_files)
    SimpleCov.expects(:add_not_loaded_files).returns({})
    SimpleCov::Result.any_instance.expects(:format!)
    SimpleCov.stubs(:root)

    Coverband::Reporters::SimpleCovReport.report(@store, open_report: false)
  end

  test 'generate scov report with additional data' do
    Coverband.configure do |config|
      config.redis             = @redis
      config.reporter          = 'scov'
      config.s3_bucket         = nil
      config.store             = @store
      config.ignore            = ['notsomething.rb']
    end

    Coverband::Reporters::SimpleCovReport.expects(:current_root).at_least_once.returns('/tmp/root_dir')

    @redis.sadd(BASE_KEY, 'test/unit/dog.rb')
    @store.send(:store_map, 'fakechecksum', "#{BASE_KEY}.test/unit/dog.rb", example_hash)
    SimpleCov.expects(:track_files)
    SimpleCov.expects(:add_not_loaded_files).returns('fake_file.rb' => [1])
    SimpleCov::Result.any_instance.expects(:format!)
    SimpleCov.stubs(:root)


    Coverband.configuration.logger.stubs('info')
    additional_data = [
      fake_coverage_report
    ]

    Coverband::Reporters::SimpleCovReport.report(@store, open_report: false, additional_scov_data: additional_data)
  end
end
