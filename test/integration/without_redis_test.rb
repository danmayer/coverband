# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

# Redis is an optional dependency since 7.0. Bundler puts the redis gem on the
# load path for the suite, so a fresh process makes it unloadable to check how
# Coverband behaves for an app that never installed it.
class WithoutRedisTest < Minitest::Test
  def skip_coverband_test_reset?
    true
  end

  HIDE_REDIS = <<~'RUBY'
    module Kernel
      alias_method :require_without_hidden_redis, :require

      def require(name)
        raise LoadError, "cannot load such file -- #{name}" if name == "redis" || name.start_with?("redis/")

        require_without_hidden_redis(name)
      end
    end
  RUBY

  def run_without_redis(script)
    Dir.mktmpdir("coverband-without-redis") do |root|
      Open3.capture3(
        {"COVERBAND_DISABLE_AUTO_START" => "1"},
        RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), "-e", HIDE_REDIS + script, root,
        chdir: root
      )
    end
  end

  def test_default_store_warns_and_records_nothing
    output, error, status = run_without_redis(<<~RUBY)
      require "coverband"
      require "stringio"

      abort "redis was loaded" if defined?(::Redis)
      log = StringIO.new
      Coverband.configure do |config|
        config.root = ARGV.fetch(0)
        config.logger = Logger.new(log)
      end
      puts Coverband.configuration.store.class
      puts log.string
    RUBY

    assert status.success?, error
    assert_match "Coverband::Adapters::NullStore", output
    assert_match "the redis gem is not installed", output
    assert_match 'gem "redis"', output
  end

  def test_configured_store_works
    output, error, status = run_without_redis(<<~RUBY)
      require "coverband"

      Coverband.configure do |config|
        config.root = ARGV.fetch(0)
        config.store = Coverband::Adapters::FileStore.new(File.join(ARGV.fetch(0), "coverage"))
      end
      Coverband.configuration.store.save_report({File.join(ARGV.fetch(0), "app.rb") => [1, 0]})
      puts Coverband.configuration.store.class
      puts Coverband.redis_connection_errors.inspect
    RUBY

    assert status.success?, error
    assert_match "Coverband::Adapters::FileStore", output
    assert_match "[]", output
  end
end
