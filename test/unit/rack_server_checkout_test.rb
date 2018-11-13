# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class RackServerCheckTest < Test::Unit::TestCase

  test 'returns true when running in rack server' do
    caller_locations = ['blah/lib/rack/server.rb'].map{ |path| OpenStruct.new(path: path) }
    Kernel.expects(:caller_locations).returns(caller_locations)
    assert_true(Coverband::RackServerCheck.running?)
  end

  test 'returns false when not running in rack server' do
    caller_locations = ['blah/lib/sidekiq/worker.rb'].map{ |path| OpenStruct.new(path: path) }
    Kernel.expects(:caller_locations).returns(caller_locations)
    assert_false(Coverband::RackServerCheck.running?)
  end
end
