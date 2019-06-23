# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

class AdaptersBaseTest < Minitest::Test

  def test_abstract_methods
    abstract_methods = %w(clear! clear_file! migrate! size save_coverage coverage)
    abstract_methods.each do |method|
      assert_raises RuntimeError do
        Coverband::Adapters::Base.new.send(method.to_sym)
      end
    end
  end

  def test_size_in_mib
    base = Coverband::Adapters::Base.new
    def base.size
      3.0
    end
    assert_equal "0.00", base.size_in_mib
  end

  def test_array_add
    original = [5, 7, nil, nil]
    latest = [3, 4, nil, 1]
    assert_equal [8, 11, nil, nil], Coverband::Adapters::Base.new.send(:array_add, latest, original)
    Coverband.configuration.stubs(:use_oneshot_lines_coverage).returns(true)
    assert_equal [1, 1, nil, nil], Coverband::Adapters::Base.new.send(:array_add, latest, original)
    Coverband.configuration.stubs(:use_oneshot_lines_coverage).returns(false)
    Coverband.configuration.stubs(:simulate_oneshot_lines_coverage).returns(true)
    assert_equal [1, 1, nil, nil], Coverband::Adapters::Base.new.send(:array_add, latest, original)
  end

  describe 'Coverband::Adapters::Base using file' do
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
end
