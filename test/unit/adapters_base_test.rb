# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class AdaptersBaseTest < Test::Unit::TestCase
  def setup
    @test_file_path = '/tmp/coverband_filestore_test_path.json'
    @store = Coverband::Adapters::FileStore.new(@test_file_path)
  end

  def test_covered_merge
    old_report = { '/Users/danmayer/projects/coverband_demo/config/coverband.rb' => [5, 7, nil],
                   '/Users/danmayer/projects/coverband_demo/config/initializers/assets.rb' => [5, 5, nil],
                   '/Users/danmayer/projects/coverband_demo/config/initializers/cookies_serializer.rb' => [5, 5, nil] }
    new_report = { '/Users/danmayer/projects/coverband_demo/config/coverband.rb' => [5, 7, nil],
                   '/Users/danmayer/projects/coverband_demo/config/initializers/filter_logging.rb' => [5, 5, nil],
                   '/Users/danmayer/projects/coverband_demo/config/initializers/wrap_parameters.rb' => [5, 5, nil],
                   '/Users/danmayer/projects/coverband_demo/app/controllers/application_controller.rb' => [5, 5, nil] }
    expected_result = {
      '/Users/danmayer/projects/coverband_demo/app/controllers/application_controller.rb' => [5, 5, nil],
      '/Users/danmayer/projects/coverband_demo/config/coverband.rb' => [10, 14, nil],
      '/Users/danmayer/projects/coverband_demo/config/initializers/assets.rb' => [5, 5, nil],
      '/Users/danmayer/projects/coverband_demo/config/initializers/cookies_serializer.rb' => [5, 5, nil],
      '/Users/danmayer/projects/coverband_demo/config/initializers/filter_logging.rb' => [5, 5, nil],
      '/Users/danmayer/projects/coverband_demo/config/initializers/wrap_parameters.rb' => [5, 5, nil]
    }
    assert_equal expected_result, @store.send(:merge_reports, new_report, old_report)
  end
end
