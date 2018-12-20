# frozen_string_literal: true

require File.expand_path('../rails_test_helper', File.dirname(__FILE__))

class RailsFullStackTest < ActionDispatch::IntegrationTest
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def setup
    Coverband::Test.reset
    #The normal relative directory lookup of coverband won't work for our dummy rails project
    Coverband.configure("./test/rails#{Rails::VERSION::MAJOR}_dummy/config/coverband.rb")
    Coverband.start
  end

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver
    ENV['COVERBAND_CONFIG'] = nil
  end

  test 'this is how we do it' do
    visit '/dummy/show'
    assert_content('I am no dummy')
    sleep 0.2
    visit '/coverage'
    click_link "view coverage report"
    within page.find('a',  text: /dummy_controller.rb/).find(:xpath, "../..") do
      assert_selector('td', text: '100.0 %')
    end
  end

  ###
  # Please keep this test starting on line 22
  # as we run it in single test mode via the benchmarks.
  # Add new tests below this test
  ###
  test 'memory usage' do
    return unless ENV['COVERBAND_MEMORY_TEST']
    # we don't want this to run during our standard test suite
    # as the below profiler changes the runtime
    # and shold only be included for isolated processes
    begin
      require 'memory_profiler'

      # warmup
      3.times do
        get '/dummy/show'
        assert_response :success
        Coverband::Collectors::Coverage.instance.report_coverage(true)
      end

      previous_out = $stdout
      capture = StringIO.new
      $stdout = capture

      MemoryProfiler.report do
        15.times do
          get '/dummy/show'
          assert_response :success
          Coverband::Collectors::Coverage.instance.report_coverage(true)
          # this is expected to retain memory across requests
          # clear it to remove the false positive from test
          Coverband::Collectors::Coverage.instance.send(:add_previous_results, nil)
        end
      end.pretty_print
      data = $stdout.string
      $stdout = previous_out
      if data.match(/retained objects by gem(.*)retained objects by file/m)[0]&.match(/coverband/)
        raise 'leaking memory!!!'
      end
    ensure
      $stdout = previous_out
    end
  end
end
