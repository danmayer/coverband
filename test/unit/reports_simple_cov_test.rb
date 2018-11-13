# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class ReportsSimpleCovTest < Test::Unit::TestCase
  BASE_KEY = Coverband::Adapters::RedisStore::BASE_KEY

  def setup
    @redis = Redis.new
    @store = Coverband::Adapters::RedisStore.new(@redis)
    @store.clear!
  end

  test 'generate scov report' do
    Coverband.configure do |config|
      config.reporter          = 'scov'
      config.store             = @store
      config.s3_bucket         = nil
      config.ignore            = ['notsomething.rb']
    end
    Coverband.configuration.logger.stubs('info')
    mock_file_hash
    @store.send(:save_report, basic_coverage)

    SimpleCov.expects(:track_files)
    SimpleCov.expects(:add_not_loaded_files).returns({})
    SimpleCov::Result.any_instance.expects(:format!)
    SimpleCov.stubs(:root)

    Coverband::Reporters::SimpleCovReport.report(@store, open_report: false)
  end
end
