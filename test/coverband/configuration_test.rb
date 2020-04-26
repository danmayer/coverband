# frozen_string_literal: true

require File.expand_path("../test_helper", File.dirname(__FILE__))

class BaseTest < Minitest::Test
  def setup
    super
    Coverband.configuration.reset
    Coverband.configure do |config|
      config.root = Dir.pwd
      config.root_paths = ["/app_path/"]
      config.ignore = ["config/envionments"]
      config.reporter = "std_out"
      config.store = Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
    end
  end

  test "ignore works with equal" do
    Coverband::Collectors::Coverage.instance.reset_instance
    expected = ["vendor/", ".erb$", ".slim$", "/tmp", "internal:prelude", "schema.rb", "config/envionments"]
    assert_equal expected, Coverband.configuration.ignore
  end

  test "ignore works with plus equal" do
    Coverband.configure do |config|
      config.ignore += ["config/initializers"]
    end
    Coverband::Collectors::Coverage.instance.reset_instance
    expected = ["vendor/",
                ".erb$",
                ".slim$",
                "/tmp",
                "internal:prelude",
                "schema.rb",
                "config/envionments",
                "config/initializers"]
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
    # it would extend the root_paths instance variable on each invokation
    Coverband.configuration.all_root_paths
    Coverband.configuration.all_root_paths
    assert_equal current_paths, Coverband.configuration.root_paths
  end

  test "store raises issues" do
    Coverband::Collectors::Coverage.instance.reset_instance
    assert_raises RuntimeError do
      Coverband.configure do |config|
        config.store = "fake"
      end
    end
  end

  test "use_oneshot_lines_coverage" do
    refute Coverband.configuration.use_oneshot_lines_coverage

    Coverband.configuration.stubs(:one_shot_coverage_implemented_in_ruby_version?).returns(true)
    Coverband.configuration.use_oneshot_lines_coverage = true
    assert Coverband.configuration.use_oneshot_lines_coverage

    Coverband.configuration.use_oneshot_lines_coverage = false
    refute Coverband.configuration.use_oneshot_lines_coverage

    Coverband.configuration.stubs(:one_shot_coverage_implemented_in_ruby_version?).returns(false)
    exception = assert_raises Exception {
      Coverband.configuration.use_oneshot_lines_coverage = true
    }
    assert_equal "One shot line coverage is only available in ruby >= 2.6", exception.message
    refute Coverband.configuration.use_oneshot_lines_coverage
  end
end
