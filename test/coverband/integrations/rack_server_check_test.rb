# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

class RackServerCheckTest < Minitest::Test
  test 'returns true when running in rack server' do
    caller_locations = ['blah/lib/rack/server.rb'].map { |path| OpenStruct.new(path: path, label: 'foo') }
    Kernel.expects(:caller_locations).returns(caller_locations)
    assert(Coverband::RackServerCheck.running?)
  end

  test 'returns false when not running in rack server' do
    caller_locations = ['blah/lib/sidekiq/worker.rb'].map { |path| OpenStruct.new(path: path, label: 'foo') }
    Kernel.expects(:caller_locations).returns(caller_locations)
    refute(Coverband::RackServerCheck.running?)
  end

  test 'returns true if running within a rails server' do
    caller_locations = [OpenStruct.new(path: '/lib/rails/commands/commands_tasks.rb', label: 'server')]
    Kernel.expects(:caller_locations).returns(caller_locations)
    assert(Coverband::RackServerCheck.running?)
  end
end
