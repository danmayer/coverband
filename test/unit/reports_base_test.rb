# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class ReportsBaseTest < Minitest::Test
  test 'filename_from_key fix filename from a key with a swappable path' do
    Coverband.configure do |config|
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = '/app/is/a/path.rb'
    # the code takes config.root expands and adds a '/' for the final path in roots
    roots = ['/app/', '/full/remote_app/path/']

    expected_path = '/full/remote_app/path/is/a/path.rb'
    File.expects(:exist?).with(key).returns(false)
    File.expects(:exist?).with(expected_path).returns(true)
    assert_equal expected_path, Coverband::Reporters::Base.send(:filename_from_key, key, roots)
  end

  test 'filename_from_key fix filename a changing deploy path with double quotes' do
    Coverband.configure do |config|
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = '/box/apps/app_name/releases/20140725203539/app/models/user.rb'
    # the code takes config.root expands and adds a '/' for the final path in roots
    # note to get regex to work for changing deploy directories
    # it must be double escaped in double quotes or use single qoutes
    roots = ['/box/apps/app_name/releases/\\d+/', '/full/remote_app/path/']

    expected_path = '/full/remote_app/path/app/models/user.rb'
    File.expects(:exist?).with('/box/apps/app_name/releases/\\d+/app/models/user.rb').returns(false)
    File.expects(:exist?).with(expected_path).returns(true)
    assert_equal expected_path, Coverband::Reporters::Base.send(:filename_from_key, key, roots)
  end

  test 'filename_from_key fix filename a changing deploy path with single quotes' do
    Coverband.configure do |config|
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = '/box/apps/app_name/releases/20140725203539/app/models/user.rb'
    # the code takes config.root expands and adds a '/' for the final path in roots
    # note to get regex to work for changing deploy directories
    # it must be double escaped in double quotes or use single qoutes
    roots = ['/box/apps/app_name/releases/\d+/', '/full/remote_app/path/']

    expected_path = '/full/remote_app/path/app/models/user.rb'
    File.expects(:exist?).with('/box/apps/app_name/releases/\\d+/app/models/user.rb').returns(false)
    File.expects(:exist?).with(expected_path).returns(true)
    assert_equal expected_path, Coverband::Reporters::Base.send(:filename_from_key, key, roots)
  end

  test 'filename_from_key leave filename from a key with a local path' do
    Coverband.configure do |config|
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = '/full/remote_app/path/is/a/path.rb'
    # the code takes config.root expands and adds a '/' for the final path in roots
    roots = ['/app/', '/full/remote_app/path/']

    expected_path = '/full/remote_app/path/is/a/path.rb'
    assert_equal expected_path, Coverband::Reporters::Base.send(:filename_from_key, key, roots)
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
    @redis = Redis.new
    store = Coverband::Adapters::RedisStore.new(@redis)
    store.clear!

    Coverband.configure do |config|
      config.reporter          = 'std_out'
      config.ignore            = %w(vendor .erb$ .slim$)
      config.root              = '/full/remote_app/path'
      config.store             = store
    end

    key = '/a_path/that_has_erb_in/thepath.rb'
    roots = ['/app/', '/full/remote_app/path/']

    lines_hit = [1, 3, 6]
    store.stubs(:coverage).returns(key => lines_hit)
    expected = { key => [1, 3, 6] }

    assert_equal expected, Coverband::Reporters::Base.send(:get_current_scov_data_imp, store, roots)
  end
end
