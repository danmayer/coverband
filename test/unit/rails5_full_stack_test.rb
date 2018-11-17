# frozen_string_literal: true

require File.expand_path('../rails5_test_helper', File.dirname(__FILE__))

class Rails5FullStackTest < ActionDispatch::IntegrationTest
  def setup
    Coverband.configuration.store.clear!
  end

  test 'this is how we do it' do
    get '/dummy/show'
    assert_response :success
    assert_equal "I am no dummy", response.body
    assert_equal [1, 1, 1, nil, nil], Coverband.configuration.store.coverage["#{Rails.root}/app/controllers/dummy_controller.rb"]
  end
end
