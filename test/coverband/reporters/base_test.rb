# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

class ReportsBaseTest < Minitest::Test
  def setup
    super
  end

  test '#merge_arrays basic merge preserves order and counts' do
    first = [0, 0, 1, 0, 1]
    second = [nil, 0, 1, 0, 0]
    expects = [0, 0, 2, 0, 1]

    assert_equal expects, Coverband::Reporters::Base.send(:merge_arrays, first, second)
  end

  test '#merge_arrays basic merge preserves order and counts different lengths' do
    first = [0, 0, 1, 0, 1]
    second = [nil, 0, 1, 0, 0, 0, 0, 1]
    expects = [0, 0, 2, 0, 1, 0, 0, 1]

    assert_equal expects, Coverband::Reporters::Base.send(:merge_arrays, first, second)
  end

  test '#merge_arrays basic merge preserves nils' do
    first = [0, 1, 2, nil, nil, nil]
    second = [0, 1, 2, nil, 0, 1, 2]
    expects = [0, 2, 4, nil, 0, 1, 2]

    assert_equal expects, Coverband::Reporters::Base.send(:merge_arrays, first, second)
  end

  test "#get_current_scov_data_imp doesn't ignore folders with default ignore keys" do
    Coverband.configure do |config|
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = '/a_path/that_has_erb_in/thepath.rb'
    roots = ['/app/', '/full/remote_app/path/']

    lines_hit = [1, 3, 6]
    store.stubs(:merged_coverage).returns(key => lines_hit)
    expected = { key => [1, 3, 6] }

    assert_equal expected, Coverband::Reporters::Base.send(:get_current_scov_data_imp, store, roots)[:merged]
  end
end
