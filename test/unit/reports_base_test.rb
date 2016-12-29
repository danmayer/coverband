require File.expand_path('../test_helper', File.dirname(__FILE__))

class ReportsBaseTest < Test::Unit::TestCase

  test "filename_from_key fix filename from a key with a swappable path" do
    Coverband.configure do |config|
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = "/app/is/a/path.rb"
    #the code takes config.root expands and adds a '/' for the final path in roots
    roots = ["/app/", '/full/remote_app/path/']

    assert_equal "/full/remote_app/path/is/a/path.rb", Coverband::Reporters::Base.filename_from_key(key, roots)
  end

  test "filename_from_key fix filename a changing deploy path with double quotes" do
    Coverband.configure do |config|
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = "/box/apps/app_name/releases/20140725203539/app/models/user.rb"
    # the code takes config.root expands and adds a '/' for the final path in roots
    # note to get regex to work for changing deploy directories it must be double escaped in double quotes or use single qoutes
    roots = ["/box/apps/app_name/releases/\\d+/", '/full/remote_app/path/']

    assert_equal "/full/remote_app/path/app/models/user.rb", Coverband::Reporters::Base.filename_from_key(key, roots)
  end

  test "filename_from_key fix filename a changing deploy path with single quotes" do
    Coverband.configure do |config|
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = "/box/apps/app_name/releases/20140725203539/app/models/user.rb"
    # the code takes config.root expands and adds a '/' for the final path in roots
    # note to get regex to work for changing deploy directories it must be double escaped in double quotes or use single qoutes
    roots = ['/box/apps/app_name/releases/\d+/', '/full/remote_app/path/']

    assert_equal "/full/remote_app/path/app/models/user.rb", Coverband::Reporters::Base.filename_from_key(key, roots)
  end

  test "filename_from_key leave filename from a key with a local path" do
    Coverband.configure do |config|
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = "/full/remote_app/path/is/a/path.rb"
    #the code takes config.root expands and adds a '/' for the final path in roots
    roots = ["/app/", '/full/remote_app/path/']

    assert_equal "/full/remote_app/path/is/a/path.rb", Coverband::Reporters::Base.filename_from_key(key, roots)
  end

  test "line_hash gets correct hash entry for a line key" do
    @fake_redis = fake_redis
    store = Coverband::Adapters::RedisStore.new(@fake_redis, array: true)

    Coverband.configure do |config|
      config.redis             = @fake_redis
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = "/full/remote_app/path/is/a/path.rb"
    #the code takes config.root expands and adds a '/'
    roots = ["/app/", '/full/remote_app/path/']

    lines_hit = ['1','3','6']
    @fake_redis.stubs(:smembers).returns(lines_hit)
    #expects to show hit counts on 1,3,6
    expected = {"/full/remote_app/path/is/a/path.rb" => [1,0,1,0,0,1]}
    File.stubs(:exists?).returns(true)
    File.stubs(:foreach).returns(['line 1','line2','line3','line4','line5','line6'])
    
    assert_equal expected, Coverband::Reporters::Base.line_hash(store, key, roots)
  end

  test "line_hash adjusts relative paths" do
    @fake_redis = fake_redis
    store = Coverband::Adapters::RedisStore.new(@fake_redis, array: true)

    Coverband.configure do |config|
      config.redis             = @fake_redis
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = "./is/a/path.rb"
    #the code takes config.root expands and adds a '/'
    roots = ["/app/", '/full/remote_app/path/']

    lines_hit = ['1','3','6']
    @fake_redis.stubs(:smembers).returns(lines_hit)
    #expects to show hit counts on 1,3,6
    expected = {"/full/remote_app/path/is/a/path.rb" => [1,0,1,0,0,1]}
    File.stubs(:exists?).returns(true)
    File.stubs(:foreach).returns(['line 1','line2','line3','line4','line5','line6'])
    
    assert_equal expected, Coverband::Reporters::Base.line_hash(store, key, roots)
  end

  test "#merge_arrays basic merge preserves order and counts" do
    first = [0,0,1,0,1]
    second = [nil,0,1,0,0]
    expects = [0,0,2,0,1]

    assert_equal expects, Coverband::Reporters::Base.merge_arrays(first, second)
  end

  test "#merge_arrays basic merge preserves order and counts different lenths" do
    first = [0,0,1,0,1]
    second = [nil,0,1,0,0,0,0,1]
    expects = [0,0,2,0,1,0,0,1]

    assert_equal expects, Coverband::Reporters::Base.merge_arrays(first, second)
  end

  test "#merge_existing_coverage basic merge preserves order and counts different lenths" do
    first = {"file.rb" => [0,1,2,nil,nil,nil]}
    second = {"file.rb" => [0,1,2,nil,0,1,2]}
    expects = {"file.rb" => [0,2,4,nil,0,1,2]}

    assert_equal expects, Coverband::Reporters::Base.merge_existing_coverage(first, second)
  end

end
