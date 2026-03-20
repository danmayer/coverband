# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

if defined?(RubyVM::AbstractSyntaxTree)
  require "coverband/utils/dead_methods"
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
          coverage = [nil, nil, 1, 1, 0, nil, nil, 1, nil, 1, nil, nil]
          dead_methods =
            DeadMethods.scan(file_path: file_path, coverage: coverage)
          assert_equal(1, dead_methods.length)
          dead_method = dead_methods.first
          assert_equal(4, dead_method.first_line_number)
          assert_equal(6, dead_method.last_line_number)
          assert_equal(file_path, dead_method.file_path)
        end

        def test_all_dead_methods
          require_unique_file
          @coverband.report_coverage
          dead_methods = DeadMethods.scan_all
          dead_method = dead_methods.find { |method| method.class_name == :Dog }
          assert(dead_method)
          assert_equal(4, dead_method.first_line_number)
          assert_equal(6, dead_method.last_line_number)
        end

        def test_all_dead_methods_on_runtime
          @coverband.eager_loading!
          require_unique_file
          @coverband.report_coverage
          @coverband.runtime!
          dead_methods = DeadMethods.scan_all
          dead_method = dead_methods.find { |method| method.class_name == :Dog }
          assert(dead_method)
          assert_equal(4, dead_method.first_line_number)
          assert_equal(6, dead_method.last_line_number)
        end

        def test_scan_all_skips_missing_files
          missing_file = "./test/fixtures/missing_file.rb"
          existing_file = "./test/dog.rb"
          coverage_report = {
            Coverband::MERGED_TYPE => {
              missing_file => { "data" => [] },
              existing_file => { "data" => [] }
            }
          }
          dead_method = Object.new

          Coverband.configuration.stubs(:store).returns(
            stub(get_coverage_report: coverage_report)
          )
          DeadMethods.expects(:scan).with(file_path: existing_file, coverage: []).returns([dead_method])
          DeadMethods.expects(:scan).with(file_path: missing_file, coverage: []).never

          assert_equal [dead_method], DeadMethods.scan_all
        end

        def test_output_all
          require_unique_file
          @coverband.report_coverage
          DeadMethods.output_all
        end

        def test_dog_methods_not_dead
          file = require_unique_file
          coverage = [nil, nil, 1, 1, 1, nil, nil, 1, nil, 1, nil, nil]
          assert_empty(DeadMethods.scan(file_path: file, coverage: coverage))
        end
      end
    end
  end
end
