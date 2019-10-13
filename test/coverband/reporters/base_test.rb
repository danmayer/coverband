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

  ###
  # This test uses real world example data which helped uncover a bug
  # The copied data doesn't format easily and isn't worth the effort to meet
  # string style
  # rubocop:disable all
  ###
  test '#get_current_scov_data_imp merges multiples of file data' do
    skip "@danmayer to take a closer look at this one"
    coverage = {'/base/66/app/controllers/dashboard_controller.rb' =>
       {"first_updated_at"=>1549610119,
        "last_updated_at"=>1549610200,
        "file_hash"=>"14dc84e940e26cbfb9ac79b43862e762",
        "data"=>[1, 1, 1, nil, 1, 1, nil, nil, 1, nil, 1, 26, 26, nil, 26, 26, 26, 26, 26, 26, 26, nil, nil, 1, nil, 1, 26, 19, 0, 0, 0, 0, nil, nil, nil, nil, 0, 0, nil, nil, 1, 26, 26, 26, nil, nil, nil, nil, nil, 1, 26, nil, nil, 1, 26, nil, nil]},
     '/base/78/app/controllers/dashboard_controller.rb' =>
       {"first_updated_at"=>1549658574,
        "last_updated_at"=>1549729830,
        "file_hash"=>"14dc84e940e26cbfb9ac79b43862e762",
        "data"=>[21, 21, 21, nil, 21, 21, nil, nil, 21, nil, 21, 22, 22, nil, 22, 22, 22, 22, 22, 22, 22, nil, nil, 21, nil, 21, 22, 13, 0, 0, 0, 0, nil, nil, nil, nil, 0, 0, nil, nil, 21, 22, 22, 22, nil, nil, nil, nil, nil, 21, 22, nil, nil, 21, 22, nil, nil]},
    '/base/70/app/controllers/dashboard_controller.rb' =>
       {"first_updated_at"=>1549617873,
        "last_updated_at"=>1549618094,
        "file_hash"=>"14dc84e940e26cbfb9ac79b43862e762",
        "data"=>[16, 16, 16, nil, 16, 16, nil, nil, 16, nil, 16, 32, 32, nil, 32, 32, 32, 32, 32, 32, 32, nil, nil, 16, nil, 16, 32, 23, 0, 0, 0, 0, nil, nil, nil, nil, 0, 0, nil, nil, 16, 32, 32, 32, nil, nil, nil, nil, nil, 16, 32, nil, nil, 16, 32, nil, nil]}
      }
    key = '/base/78/app/app/controllers/dashboard_controller.rb'
    roots = ['/base/[0-9]*/', '/base/78/app/']

    Coverband.configuration.stubs(:all_root_paths).returns(roots)
    lines_hit = [1, 3, 6]
    store.stubs(:merged_coverage).returns(coverage)
    File.expects(:exist?).at_least_once
      .with('/base/[0-9]*/app/controllers/dashboard_controller.rb')
      .returns(false)
    File.expects(:exist?).at_least_once.with(key).returns(true)

    expected = {"first_updated_at"=>1549617873,
                "last_updated_at"=>1549618094,
                "file_hash"=>"14dc84e940e26cbfb9ac79b43862e762",
                "data"=>[38, 38, 38, nil, 38, 38, nil, nil, 38, nil, 38, 80, 80, nil, 80, 80, 80, 80, 80, 80, 80, nil, nil, 38, nil, 38, 80, 55, 0, 0, 0, 0, nil, nil, nil, nil, 0, 0, nil, nil, 38, 80, 80, 80, nil, nil, nil, nil, nil, 38, 80, nil, nil, 38, 80, nil, nil]}
    assert_equal expected, Coverband::Reporters::Base.send(:get_current_scov_data_imp, store, roots)[:merged][key]
  end

end
