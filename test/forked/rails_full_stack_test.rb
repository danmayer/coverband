# frozen_string_literal: true

require File.expand_path('../rails_test_helper', File.dirname(__FILE__))

class RailsFullStackTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def setup
    super
    rails_setup
    # preload first coverage hit
    Coverband::Collectors::Coverage.instance.report_coverage(true)
    require 'rainbow'
    Rainbow('this text is red').red
  end

  def teardown
    super
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end

  # We have to combine everything in one test
  # because we can only initialize rails once per test
  # run. Possibly fork test runs to avoid this problem in future?
  test 'this is how we do it' do
    visit '/dummy/show'
    Coverband.report_coverage(true)
    assert_content('I am no dummy')
    visit '/coverage'
    within page.find('a', text: /dummy_controller.rb/).find(:xpath, '../..') do
      assert_selector('td', text: '100.0 %')
    end

    # Test gems are reporting coverage
    assert_content('Gems')
    assert page.html.match('rainbow/wrapper.rb')

    # Test eager load data stored separately
    dummy_controller = "./test/rails#{Rails::VERSION::MAJOR}_dummy/app/controllers/dummy_controller.rb"
    store.type = :eager_loading
    eager_expected = [1, 1, 0, nil, nil]
    results = store.coverage[dummy_controller]['data']
    assert_equal(eager_expected, results)

    store.type = nil
    runtime_expected = [0, 0, 1, nil, nil]
    results = store.coverage[dummy_controller]['data']
  end

  ###
  # Please keep this test starting on line 22
  # as we run it in single test mode via the benchmarks.
  # Add new tests below this test
  ###
  if ENV['COVERBAND_MEMORY_TEST']
    test 'memory usage' do
      return unless ENV['COVERBAND_MEMORY_TEST']

      # we don't want this to run during our standard test suite
      # as the below profiler changes the runtime
      # and shold only be included for isolated processes
      begin
        require 'memory_profiler'

        # warmup
        3.times do
          visit '/dummy/show'
          assert_content('I am no dummy')
          Coverband.report_coverage(true)
        end

        previous_out = $stdout
        capture = StringIO.new
        $stdout = capture

        MemoryProfiler.report do
          15.times do
            visit '/dummy/show'
            assert_content('I am no dummy')
            Coverband.report_coverage(true)
            # this is expected to retain memory across requests
            # clear it to remove the false positive from test
            Coverband::Collectors::Coverage.instance.send(:add_previous_results, nil)
          end
        end.pretty_print
        data = $stdout.string
        $stdout = previous_out
        raise 'leaking memory!!!' if data.match(/retained objects by gem(.*)retained objects by file/m)[0]&.match(/coverband/)
      ensure
        $stdout = previous_out
      end
    end
  end
end
