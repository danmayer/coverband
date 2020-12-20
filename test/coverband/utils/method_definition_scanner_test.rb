# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

if defined?(RubyVM::AbstractSyntaxTree)
  module Coverband
    module Utils
      class MethodBodyTest < Minitest::Test
        def test_no_method_body_coverage
          method_body = MethodDefinitionScanner::MethodBody.new(MethodDefinitionScanner::MethodDefinition.new(first_line_number: 4, last_line_number: 6, name: :bark))
          refute(method_body.coverage?([nil, nil, 1, 1, 0, nil, 1]))
        end

        def test_method_body_coverage
          method_body = MethodDefinitionScanner::MethodBody.new(MethodDefinitionScanner::MethodDefinition.new(first_line_number: 4, last_line_number: 6, name: :bark))
          assert(method_body.coverage?([nil, nil, 1, 1, 1, nil, 1]))
        end
      end

      class MethodDefinitionScannerTest < Minitest::Test
        def test_scan
          method_definitions = MethodDefinitionScanner.scan("./test/dog.rb")
          assert(method_definitions)
          assert_equal(1, method_definitions.length)
          method_definition = method_definitions.first # assert_equal(4, method.first_line)
          assert_equal(4, method_definition.first_line_number)
          assert_equal(6, method_definition.last_line_number)
          assert_equal(:bark, method_definition.name)
        end

        def test_scan_large_class
          method_definitions =
            MethodDefinitionScanner.scan("./test/fixtures/casting_invitor.rb")
          method_first_line_numbers = method_definitions.map(&:first_line_number)
          assert_equal([6, 13, 17, 35, 40, 44, 48, 52], method_first_line_numbers)
          method_last_line_numbers = method_definitions.map(&:last_line_number)
          assert_equal([11, 15, 31, 38, 42, 46, 50, 59], method_last_line_numbers)
        end
      end
    end
  end
end
