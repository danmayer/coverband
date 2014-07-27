require File.expand_path('../test_helper', File.dirname(__FILE__))

class ReporterTest < Test::Unit::TestCase

  test "record baseline" do
    Coverage.expects(:start).at_least_once
    Coverage.expects(:result).returns({'fake' => [0,1]}).at_least_once
    File.expects(:open).once

    Coverband::Reporter.stubs(:puts)

    Coverband::Reporter.baseline{
      #nothing
    }
  end

  test "report data" do
    Coverband.configure do |config|
      config.redis             = fake_redis
      config.reporter          = 'std_out'
    end

    Coverband::Reporter.expects(:current_root).returns('/root_dir')
    fake_redis.expects(:smembers).with('coverband').returns(fake_coverband_members)
    
    fake_coverband_members.each do |key|
      fake_redis.expects(:smembers).with("coverband.#{key}").returns(["54", "55"])
    end

    matchers = [regexp_matches(/tester/),
                regexp_matches(/application_controller/),
                regexp_matches(/account/),
                regexp_matches(/54/)]
    
    Coverband.configuration.logger.expects('info').with(all_of(*matchers))

    Coverband::Reporter.report
  end


  ####
  # TODO
  # attempting to write some tests around this reporter
  # shows that it has become a disaster of self methods relying on side effects.
  # Fix to standard class and methods.
  ####
  test "filename_from_key fix filename from a key with a swappable path" do
    Coverband.configure do |config|
      config.redis             = fake_redis
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = "/app/is/a/path.rb"
    #the code takes config.root expands and adds a '/' for the final path in roots
    roots = ["/app/", '/full/remote_app/path/']

    assert_equal "/full/remote_app/path/is/a/path.rb", Coverband::Reporter.filename_from_key(key, roots)
  end

  test "filename_from_key fix filename a changing deploy path with double quotes" do
    Coverband.configure do |config|
      config.redis             = fake_redis
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = "/box/apps/app_name/releases/20140725203539/app/models/user.rb"
    # the code takes config.root expands and adds a '/' for the final path in roots
    # note to get regex to work for changing deploy directories it must be double escaped in double quotes or use single qoutes
    roots = ["/box/apps/app_name/releases/\\d+/", '/full/remote_app/path/']

    assert_equal "/full/remote_app/path/app/models/user.rb", Coverband::Reporter.filename_from_key(key, roots)
  end

  test "filename_from_key fix filename a changing deploy path with single quotes" do
    Coverband.configure do |config|
      config.redis             = fake_redis
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = "/box/apps/app_name/releases/20140725203539/app/models/user.rb"
    # the code takes config.root expands and adds a '/' for the final path in roots
    # note to get regex to work for changing deploy directories it must be double escaped in double quotes or use single qoutes
    roots = ['/box/apps/app_name/releases/\d+/', '/full/remote_app/path/']

    assert_equal "/full/remote_app/path/app/models/user.rb", Coverband::Reporter.filename_from_key(key, roots)
  end

  test "filename_from_key leave filename from a key with a local path" do
    Coverband.configure do |config|
      config.redis             = fake_redis
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = "/full/remote_app/path/is/a/path.rb"
    #the code takes config.root expands and adds a '/' for the final path in roots
    roots = ["/app/", '/full/remote_app/path/']

    assert_equal "/full/remote_app/path/is/a/path.rb", Coverband::Reporter.filename_from_key(key, roots)
  end

  test "line_hash gets correct hash entry for a line key" do
    Coverband.configure do |config|
      config.redis             = fake_redis
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = "/full/remote_app/path/is/a/path.rb"
    #the code takes config.root expands and adds a '/'
    roots = ["/app/", '/full/remote_app/path/']

    current_redis = fake_redis
    lines_hit = ['1','3','6']
    current_redis.stubs(:smembers).returns(lines_hit)
    #expects to show hit counts on 1,3,6
    expected = {"/full/remote_app/path/is/a/path.rb" => [1,0,1,0,0,1]}
    File.stubs(:exists?).returns(true)
    File.stubs(:foreach).returns(['line 1','line2','line3','line4','line5','line6'])
    
    assert_equal expected, Coverband::Reporter.line_hash(current_redis, key, roots)
  end

  test "line_hash adjusts relative paths" do
    Coverband.configure do |config|
      config.redis             = fake_redis
      config.reporter          = 'std_out'
      config.root              = '/full/remote_app/path'
    end

    key = "./is/a/path.rb"
    #the code takes config.root expands and adds a '/'
    roots = ["/app/", '/full/remote_app/path/']

    current_redis = fake_redis
    lines_hit = ['1','3','6']
    current_redis.stubs(:smembers).returns(lines_hit)
    #expects to show hit counts on 1,3,6
    expected = {"/full/remote_app/path/is/a/path.rb" => [1,0,1,0,0,1]}
    File.stubs(:exists?).returns(true)
    File.stubs(:foreach).returns(['line 1','line2','line3','line4','line5','line6'])
    
    assert_equal expected, Coverband::Reporter.line_hash(current_redis, key, roots)
  end

  test "#merge_arrays basic merge preserves order and counts" do
    first = [0,0,1,0,1]
    second = [nil,0,1,0,0]
    expects = [0,0,1,0,1]

    assert_equal expects, Coverband::Reporter.merge_arrays(first, second)
  end

  test "#merge_arrays basic merge preserves order and counts different lenths" do
    first = [0,0,1,0,1]
    second = [nil,0,1,0,0,0,0,1]
    expects = [0,0,1,0,1,0,0,1]

    assert_equal expects, Coverband::Reporter.merge_arrays(first, second)
  end

  private

  def fake_redis
    @redis ||= begin
                 redis = OpenStruct.new()
                 def redis.smembers(key)
                 end
                 redis
               end
  end

  def fake_coverband_members
    ["/Users/danmayer/projects/hearno/script/tester.rb",
     "/Users/danmayer/projects/hearno/app/controllers/application_controller.rb",
     "/Users/danmayer/projects/hearno/app/models/account.rb"
    ]
  end

  def fake_coverage_report
    {"/Users/danmayer/projects/hearno/script/tester.rb"=>[1, nil, 1, 1, nil, nil, nil]}
  end

end
