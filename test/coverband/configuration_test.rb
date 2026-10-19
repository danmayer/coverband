# frozen_string_literal: true

require File.expand_path("../test_helper", File.dirname(__FILE__))

class BaseTest < Minitest::Test
  def setup
    Coverband.configuration.reset
    super
    Coverband.configuration.reset
    Coverband.configure do |config|
      config.root = Dir.pwd
      config.root_paths = ["/app_path/"]
      config.ignore = ["config/environments"]
      config.store = Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
    end
  end

  test "ignore works with equal" do
    Coverband::Collectors::Coverage.instance.reset_instance
    expected = ["vendor/", "/tmp", "internal:prelude", "db/schema.rb", ".erb$", ".haml$", ".slim$", "config/environments"].map { |str| Regexp.new(str) }
    assert_equal expected, Coverband.configuration.ignore
  end

  test "ignore works with plus equal" do
    Coverband.configure do |config|
      config.ignore += ["config/initializers"]
    end
    Coverband::Collectors::Coverage.instance.reset_instance
    expected = ["vendor/",
      "/tmp",
      "internal:prelude",
      "db/schema.rb",
      ".erb$",
      ".haml$",
      ".slim$",
      "config/environments",
      "config/initializers"].map { |str| Regexp.new(str) }
    assert_equal expected, Coverband.configuration.ignore
  end

  test "ignore" do
    Coverband::Collectors::Coverage.instance.reset_instance
    assert !Coverband.configuration.ignore.first.nil?
  end

  test "all_root_paths" do
    Coverband::Collectors::Coverage.instance.reset_instance
    current_paths = Coverband.configuration.root_paths.dup
    # verify previous bug fix
    # it would extend the root_paths instance variable on each invocation
    Coverband.configuration.all_root_paths
    Coverband.configuration.all_root_paths
    assert_equal current_paths, Coverband.configuration.root_paths
  end

  test "store raises when not set to supported adapter" do
    Coverband::Collectors::Coverage.instance.reset_instance
    assert_raises RuntimeError do
      Coverband.configure do |config|
        config.store = "fake"
      end
    end
  end

  test "store defaults to redis store" do
    Coverband::Collectors::Coverage.instance.reset_instance
    assert_equal Coverband.configuration.store.class, Coverband::Adapters::RedisStore
  end

  test "removed settings are ignored with a warning saying how to upgrade" do
    Coverband::Collectors::Coverage.instance.reset_instance
    Coverband.configuration.reset
    logger = Logger.new(log = StringIO.new)
    Coverband.configure do |config|
      config.logger = logger
      config.api_key = "test-key"
      config.reporter = "std_out"
    end

    assert_match "config.api_key was removed in 7.0 and is ignored", log.string
    assert_match "coverband.io is no longer maintained", log.string
    assert_match "config.reporter was removed in 7.0 and is ignored", log.string
    assert_equal Coverband::Adapters::RedisStore, Coverband.configuration.store.class
    refute_respond_to Coverband.configuration, :api_key
  end

  test "redis_url with rediss:// scheme for TLS support" do
    Coverband::Collectors::Coverage.instance.reset_instance
    Coverband.configuration.reset
    # Verify that rediss:// URLs (TLS) can be configured
    # The Redis gem will automatically enable TLS when it sees the rediss:// scheme
    Coverband.configure do |config|
      config.redis_url = "rediss://my-elasticache.example.com:6379"
    end

    assert_equal "rediss://my-elasticache.example.com:6379", Coverband.configuration.redis_url
  end

  test "removed configuration options are not exposed" do
    removed = %i[
      s3_region
      s3_bucket
      s3_access_key_id
      s3_secret_access_key
      track_gems
      gem_details
      simulate_oneshot_lines_coverage
      reporter
      api_key
      service_url
      coverband_timeout
      service_dev_mode
      service_test_mode
      process_type
    ]
    assert_equal removed.sort, Coverband::Configuration::REMOVED_SETTINGS.keys.sort

    Coverband.configuration.logger = Logger.new(StringIO.new)
    removed.each do |setting|
      refute_respond_to Coverband.configuration, setting
      Coverband.configuration.public_send(:"#{setting}=", "value")
      refute Coverband.configuration.instance_variable_defined?(:"@#{setting}"), setting
    end
  end
end
