# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

if defined?(RubyVM::AbstractSyntaxTree)
  module Coverband
    module Utils
      class DeadMethodsTest < Minitest::Test
        attr_accessor :coverband

        def setup
          super
          @coverband = Coverband::Collectors::Coverage.instance
        end

        def test_dog_dead_methods
          file_path = require_unique_file
          coverage = [nil, nil, 1, 1, 0, nil, nil]
          dead_methods =
            DeadMethods.scan(file_path: file_path, coverage: coverage)
          assert_equal(1, dead_methods.length)
          dead_method = dead_methods.first
          assert_equal(4, dead_method.first_line_number)
          assert_equal(6, dead_method.last_line_number)
        end

        def test_dog_methods_not_dead
          file = require_unique_file
          coverage = [nil, nil, 1, 1, 1, nil, nil]
          assert_empty(DeadMethods.scan(file_path: file, coverage: coverage))
        end
      end
    end
  end
end
