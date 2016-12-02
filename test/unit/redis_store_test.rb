require File.expand_path('../test_helper', File.dirname(__FILE__))

class RedisTest < Test::Unit::TestCase

  def setup
    @redis = Redis.new
    @redis.flushdb
    @store = Coverband::RedisStore.new(@redis)
  end

  def test_covered_lines_for_file
    @redis.sadd('coverband.dog.rb', 1)
    @redis.sadd('coverband.dog.rb', 2)
    assert_equal @store.covered_lines_for_file('dog.rb').sort,  [1, 2]
  end

  def test_covered_lines_when_null
    assert_equal @store.covered_lines_for_file('dog.rb'),  []
  end

  private

  def test_data
    {
      "/Users/danmayer/projects/cover_band_server/app.rb" => { 54 => 1, 55 => 2 },
      "/Users/danmayer/projects/cover_band_server/server.rb" => { 5 => 1 }
    }
  end
end

class RedisStoreTestV3 < RedisTest

    def setup
      @redis = Redis.current.tap { |redis|
        redis.stubs(:sadd).with(anything, anything)
        redis.stubs(:info).returns({'redis_version' => 3.0})
      }

      @store = Coverband::RedisStore.new(@redis)
    end

    test "it stores the files into coverband" do
      @redis.expects(:sadd).with('coverband', [
        '/Users/danmayer/projects/cover_band_server/app.rb',
        '/Users/danmayer/projects/cover_band_server/server.rb'
      ])

      @store.store_report(test_data)
    end

    test "it stores the file lines of the file app.rb" do
      @redis.expects(:sadd).with(
        'coverband./Users/danmayer/projects/cover_band_server/app.rb',
        [54, 55]
      )

      @store.store_report(test_data)
    end

    test "it stores the file lines of the file server.rb" do
      @redis.expects(:sadd).with(
        'coverband./Users/danmayer/projects/cover_band_server/server.rb',
        [5]
      )

      @store.store_report(test_data)
    end

end

class RedisStoreTestV223 < RedisTest

    def setup
      @redis = Redis.current.tap { |redis|
        redis.stubs(:sadd).with(anything, anything)
        redis.stubs(:info).returns({'redis_version' => "2.2.3"})
      }

      @store = Coverband::RedisStore.new(@redis)
    end

    test "it store the files with separate calls into coverband" do
      @redis.expects(:sadd).with('coverband', '/Users/danmayer/projects/cover_band_server/app.rb')
      @redis.expects(:sadd).with('coverband', '/Users/danmayer/projects/cover_band_server/server.rb')

      @store.store_report(test_data)
    end
end

class RedisStoreTestV222 < RedisTest

    def setup
      @redis = Redis.current.tap { |redis|
        redis.stubs(:sadd).with(anything, anything)
        redis.stubs(:info).returns({'redis_version' => "2.2.2"})
      }

      @store = Coverband::RedisStore.new(@redis)
    end

    test "it store the files with separate calls into coverband" do
      @redis.expects(:sadd).with('coverband', '/Users/danmayer/projects/cover_band_server/app.rb')
      @redis.expects(:sadd).with('coverband', '/Users/danmayer/projects/cover_band_server/server.rb')

      @store.store_report(test_data)
    end
end
