# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

if defined?(RubyVM::AbstractSyntaxTree)
  module Coverband
    module Utils
      class MethodDefinitionTest < Minitest::Test
        def test_scan
          method_definitions = MethodDefinition.scan("./test/dog.rb")
          assert(method_definitions)
          assert_equal(1, method_definitions.length)
          method_definition = method_definitions.first # assert_equal(4, method.first_line)
          assert_equal(4, method_definition.first_line_number)
          assert_equal(6, method_definition.last_line_number)
        end

        def test_scan_large_class
          method_definitions =
            MethodDefinition.scan("./test/fixtures/casting_invitor.rb")
          method_first_line_numbers = method_definitions.map(&:first_line_number)
          assert_equal([6, 13, 17, 35, 40, 44, 48, 52], method_first_line_numbers)
          method_last_line_numbers = method_definitions.map(&:last_line_number)
          assert_equal([11, 15, 31, 38, 42, 46, 50, 59], method_last_line_numbers)
        end
      end
    end
  end
end
