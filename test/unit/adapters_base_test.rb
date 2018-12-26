# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class AdaptersBaseTest < Minitest::Test
  def setup
    super
    @test_file_path = '/tmp/coverband_filestore_test_path.json'
    @store = Coverband::Adapters::FileStore.new(@test_file_path)
    mock_file_hash
  end

  def test_covered_merge
    old_time = 1541958097
    current_time = Time.now.to_i
    old_data = {
      'first_updated_at' => old_time,
      'last_updated_at' => current_time,
      'file_hash' => 'abcd',
      'data' => [5, 7, nil]
    }
    old_report = { '/projects/coverband_demo/config/coverband.rb' => old_data,
                   '/projects/coverband_demo/config/initializers/assets.rb' => old_data,
                   '/projects/coverband_demo/config/initializers/cookies_serializer.rb' => old_data }
    new_report = { '/projects/coverband_demo/config/coverband.rb' => [5, 7, nil],
                   '/projects/coverband_demo/config/initializers/filter_logging.rb' => [5, 7, nil],
                   '/projects/coverband_demo/config/initializers/wrap_parameters.rb' => [5, 7, nil],
                   '/projects/coverband_demo/app/controllers/application_controller.rb' => [5, 7, nil] }
    expected_merge = {
      'first_updated_at' => old_time,
      'last_updated_at' => current_time,
      'file_hash' => 'abcd',
      'data' => [10, 14, nil]
    }
    new_data = {
      'first_updated_at' => current_time,
      'last_updated_at' => current_time,
      'file_hash' => 'abcd',
      'data' => [5, 7, nil]
    }
    expected_result = {
      '/projects/coverband_demo/app/controllers/application_controller.rb' => new_data,
      '/projects/coverband_demo/config/coverband.rb' => expected_merge,
      '/projects/coverband_demo/config/initializers/assets.rb' => old_data,
      '/projects/coverband_demo/config/initializers/cookies_serializer.rb' => old_data,
      '/projects/coverband_demo/config/initializers/filter_logging.rb' => new_data,
      '/projects/coverband_demo/config/initializers/wrap_parameters.rb' => new_data
    }
    assert_equal expected_result, @store.send(:merge_reports, new_report, old_report)
  end
end
