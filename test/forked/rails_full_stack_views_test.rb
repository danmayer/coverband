# frozen_string_literal: true

require File.expand_path("../rails_test_helper", File.dirname(__FILE__))

class RailsFullStackTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def setup
    super
    rails_setup
    Coverband.report_coverage
  end

  def teardown
    super
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end

  test "verify erb haml slim support" do
    visit "/dummy_view/show"
    assert_content("I am no dummy view tracker text")
    Coverband.report_coverage
    Coverband.configuration.view_tracker&.report_views_tracked
    Coverband.configuration.route_tracker&.report_routes_tracked
    visit "/coverage/view_tracker"
    assert_content("Used Views: (1)")
    assert_content("Unused Views: (2)")
    assert_selector("li.used-views", text: "dummy_view/show.html.erb")
    assert_selector("li.unused-views", text: "dummy_view/show_haml.html.haml")
    assert_selector("li.unused-views", text: "dummy_view/show_slim.html.slim")

    visit "/coverage/route_tracker"
    assert_content("Used Routes: (1)")
    assert_content("Unused Routes: (5)")

    visit "/dummy_view/show_haml"
    assert_content("I am haml text")
    Coverband.report_coverage
    Coverband.configuration.view_tracker&.report_views_tracked
    visit "/coverage/view_tracker"
    assert_content("Used Views: (2)")
    assert_content("Unused Views: (1)")
    assert_selector("li.used-views", text: "dummy_view/show_haml.html.haml")

    visit "/dummy_view/show_slim"
    assert_content("I am slim text")
    Coverband.report_coverage
    Coverband.configuration.view_tracker&.report_views_tracked
    visit "/coverage/view_tracker"
    assert_content("Used Views: (3)")
    assert_content("Unused Views: (0)")
    assert_selector("li.used-views", text: "dummy_view/show_slim.html.slim")
  end
end
