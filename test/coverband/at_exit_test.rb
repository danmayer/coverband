# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class AtExitTest < Minitest::Test
  test 'only registers once' do
    Coverband::AtExit.instance_eval { @at_exit_registered = nil }
    Coverband::AtExit.expects(:at_exit).yields.once.returns(true)
    2.times { Coverband::AtExit.register }
  end
end
