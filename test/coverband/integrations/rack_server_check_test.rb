# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class RackServerCheckTest < Minitest::Test
  # Create a Struct for the caller location at the class level
  LocationStruct = Struct.new(:path, :label)

  test "returns true when running in rack server" do
    caller_locations = ["blah/lib/rack/server.rb"].map { |path| LocationStruct.new(path, "foo") }
    Kernel.expects(:caller_locations).returns(caller_locations)
    assert(Coverband::RackServerCheck.running?)
  end

  test "returns false when not running in rack server" do
    caller_locations = ["blah/lib/sidekiq/worker.rb"].map { |path| LocationStruct.new(path, "foo") }
    Kernel.expects(:caller_locations).returns(caller_locations)
    refute(Coverband::RackServerCheck.running?)
  end

  test "returns true if running within a rails server" do
    caller_locations = [LocationStruct.new("/lib/rails/commands/commands_tasks.rb", "server")]
    Kernel.expects(:caller_locations).returns(caller_locations)
    assert(Coverband::RackServerCheck.running?)
  end
end
