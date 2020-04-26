# frozen_string_literal: true

require File.expand_path("../rails_test_helper", File.dirname(__FILE__))

class RailsFullStackTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def setup
    super
    rails_setup
    # preload first coverage hit
    Coverband.report_coverage
    require "rainbow"
    Rainbow("this text is red").red
  end

  def teardown
    super
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end

  # We have to combine everything in one test
  # because we can only initialize rails once per test
  # run. Possibly fork test runs to avoid this problem in future?
  unless ENV["COVERBAND_MEMORY_TEST"]
    test "this is how we do it" do
      visit "/dummy/show"
      Coverband.report_coverage
      assert_content("I am no dummy")
      visit "/coverage"
      within page.find("a", text: /dummy_controller.rb/).find(:xpath, "../..") do
        assert_selector("td", text: "100.0 %")
      end

      # Test eager load data stored separately
      dummy_controller = "./test/rails#{Rails::VERSION::MAJOR}_dummy/app/controllers/dummy_controller.rb"
      store.type = :eager_loading
      eager_expected = [1, 1, 0, nil, nil]
      results = store.coverage[dummy_controller]["data"]
      assert_equal(eager_expected, results)

      store.type = Coverband::RUNTIME_TYPE
      runtime_expected = [0, 0, 1, nil, nil]
      results = store.coverage[dummy_controller]["data"]
      assert_equal(runtime_expected, results)
    end
  end

  ###
  # as we run it in single test mode via the benchmarks.
  # Add new tests below this test
  ###
  if ENV["COVERBAND_MEMORY_TEST"]
    test "memory usage" do
      return unless ENV["COVERBAND_MEMORY_TEST"]

      # we don't want this to run during our standard test suite
      # as the below profiler changes the runtime
      # and shold only be included for isolated processes
      begin
        require "memory_profiler"

        # warmup
        3.times do
          visit "/dummy/show"
          assert_content("I am no dummy")
          Coverband.report_coverage
        end

        previous_out = $stdout
        capture = StringIO.new
        $stdout = capture

        MemoryProfiler.report {
          15.times do
            visit "/dummy/show"
            assert_content("I am no dummy")
            Coverband.report_coverage
            ###
            # Set to nil not {} as it is easier to verify that no memory is retained when nil gets released
            # don't use Coverband::Collectors::Delta.reset which sets to {}
            #
            # we clear this as this one variable is expected to retain memory and is a false positive
            ###
            Coverband::Collectors::Delta.class_variable_set(:@@previous_coverage, nil)
            # needed to test older versions to discover when we had the regression
            # Coverband::Collectors::Coverage.instance.send(:add_previous_results, nil)
          end
        }.pretty_print
        data = $stdout.string
        $stdout = previous_out
        if data.match(/retained objects by gem(.*)retained objects by file/m)[0]&.match(/coverband/)
          puts data
          raise "leaking memory!!!"
        end
      ensure
        $stdout = previous_out
      end
    end
  end
end
