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
      config.reporter = "std_out"
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

  test "ignore catches regex errors" do
    Coverband.configuration.logger.expects(:error).with("an invalid regular expression was passed in, ensure string are valid regex patterns *invalidRegex*")
    Coverband.configure do |config|
      config.ignore = ["*invalidRegex*"]
    end
    Coverband::Collectors::Coverage.instance.reset_instance
    expected = (Coverband::Configuration::IGNORE_DEFAULTS << "config/environments").map { |str| Regexp.new(str) }
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

  test "store is a service store when api_key is set" do
    Coverband::Collectors::Coverage.instance.reset_instance
    Coverband.configuration.reset
    Coverband.configure do |config|
      config.redis_url = nil
      config.api_key = "test-key"
    end
    assert_equal Coverband.configuration.store.class.to_s, "Coverband::Adapters::WebServiceStore"
  end

  test "store raises when api key set but not set to service" do
    Coverband::Collectors::Coverage.instance.reset_instance
    Coverband.configuration.reset
    assert_raises RuntimeError do
      Coverband.configure do |config|
        config.api_key = "test-key"
        config.redis_url = "redis://localhost:3333"
        config.store = Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
      end
    end
  end

  test "store raises when api key and coverband redis env" do
    Coverband::Collectors::Coverage.instance.reset_instance
    Coverband.configuration.reset

    env = ENV.to_hash.merge("COVERBAND_REDIS_URL" => "redis://localhost:3333")
    Object.stub_const(:ENV, env) do
      assert_raises RuntimeError do
        Coverband.configure do |config|
          config.api_key = "test-key"
        end
      end
    end
  end

  test "store doesn't raises when api key and redis_url" do
    Coverband::Collectors::Coverage.instance.reset_instance
    Coverband.configuration.reset
    Coverband.configure do |config|
      config.api_key = "test-key"
      config.redis_url = "redis://localhost:3333"
    end
  end
end
