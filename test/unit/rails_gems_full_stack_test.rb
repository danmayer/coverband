# frozen_string_literal: true

require File.expand_path('../rails_test_helper', File.dirname(__FILE__))

class RailsGemsFullStackTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def setup
    super
    # The normal relative directory lookup of coverband won't work for our dummy rails project
    Coverband.configure("./test/rails#{Rails::VERSION::MAJOR}_dummy/config/coverband.rb")
    Coverband.configuration.track_gems = true
    Coverband.configuration.gem_details = true
    Coverband.start
    require 'rainbow'
    Rainbow('this text is red').red
  end

  def teardown
    super
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end

  test 'this is how gem it' do
    visit '/dummy/show'
    assert_content('I am no dummy')
    sleep 0.2
    visit '/coverage'
    assert_content('Coverband Admin')
    assert_content('Gems')
    assert page.html.match('rainbow/wrapper.rb')
  end
end
