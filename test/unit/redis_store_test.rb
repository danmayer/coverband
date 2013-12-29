require File.expand_path('../test_helper', File.dirname(__FILE__))

class RedisStoreTest < Test::Unit::TestCase
  context '#store_report' do
    setup do
      @redis = Redis.current.tap { |redis|
        redis.stubs(:sadd).with(anything, anything)
      }

      @store = Coverband::RedisStore.new(@redis)
    end

    should "it stores the files into coverband" do
      @redis.expects(:sadd).with('coverband', [
        '/Users/danmayer/projects/cover_band_server/app.rb',
        '/Users/danmayer/projects/cover_band_server/server.rb'
      ])

      @store.store_report(test_data)
    end

    should "it stores the file lines of the file app.rb" do
      @redis.expects(:sadd).with(
        'coverband./Users/danmayer/projects/cover_band_server/app.rb',
        [54, 55]
      )

      @store.store_report(test_data)
    end

    should "it stores the file lines of the file server.rb" do
      @redis.expects(:sadd).with(
        'coverband./Users/danmayer/projects/cover_band_server/server.rb',
        [5]
      )

      @store.store_report(test_data)
    end

    context 'when the redis server version is too old' do
      setup do
        @redis.stubs(:info).returns("redis_version"=>"2.2.3")
      end

      should "it store the files with separate calls into coverband" do
        @redis.expects(:sadd).with('coverband', '/Users/danmayer/projects/cover_band_server/app.rb')
        @redis.expects(:sadd).with('coverband', '/Users/danmayer/projects/cover_band_server/server.rb')

        @store.store_report(test_data)
      end
    end

    context 'when the redis gem version is too old' do
      setup do
        @gem_version = Redis::VERSION
        Redis.send(:remove_const, :VERSION)
        Redis::VERSION = '2.2.2'
      end

      teardown do
        Redis.send(:remove_const, :VERSION)
        Redis::VERSION = @gem_version
      end

      should "it store the files with separate calls into coverband" do
        @redis.expects(:sadd).with('coverband', '/Users/danmayer/projects/cover_band_server/app.rb')
        @redis.expects(:sadd).with('coverband', '/Users/danmayer/projects/cover_band_server/server.rb')

        @store.store_report(test_data)
      end
    end
  end

  private

  def test_data
    {
      "/Users/danmayer/projects/cover_band_server/app.rb"=>[54, 55],
      "/Users/danmayer/projects/cover_band_server/server.rb"=>[5]
    }
  end
end
