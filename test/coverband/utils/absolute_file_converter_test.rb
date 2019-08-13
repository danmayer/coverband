# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

module Coverband
  module Utils
    class AbsoluteFileConverterTest < ::Minitest::Test
      def test_convert
        converter = AbsoluteFileConverter.new([FileUtils.pwd])
        assert_equal("#{FileUtils.pwd}/lib/coverband.rb", converter.convert('./lib/coverband.rb'))
      end

      def test_convert_multiple_roots
        converter = AbsoluteFileConverter.new(['/foo/bar', FileUtils.pwd])
        assert_equal("#{FileUtils.pwd}/Rakefile", converter.convert('./Rakefile'))
      end

      test 'relative_path_to_full leave filename from a key with a local path' do
        converter = AbsoluteFileConverter.new(['/app/', '/full/remote_app/path/'])
        assert_equal '/full/remote_app/path/is/a/path.rb', converter.convert('/full/remote_app/path/is/a/path.rb')
      end

      test 'relative_path_to_full fix filename from a key with a swappable path' do
        key = '/app/is/a/path.rb'
        converter = AbsoluteFileConverter.new(['/app/', '/full/remote_app/path/'])
        expected_path = '/full/remote_app/path/is/a/path.rb'
        File.expects(:exist?).with(key).returns(false)
        File.expects(:exist?).with(expected_path).returns(true)
        assert_equal expected_path, converter.convert(key)
      end

      test 'relative_path_to_full fix filename a changing deploy path with quotes' do
        converter = AbsoluteFileConverter.new(['/box/apps/app_name/releases/\\d+/', '/full/remote_app/path/'])
        expected_path = '/full/remote_app/path/app/models/user.rb'
        key = '/box/apps/app_name/releases/20140725203539/app/models/user.rb'
        File.expects(:exist?).with('/box/apps/app_name/releases/\\d+/app/models/user.rb').returns(false)
        File.expects(:exist?).with(expected_path).returns(true)
        assert_equal expected_path, converter.convert(key)
        assert_equal expected_path, converter.convert(key)
      end

      test 'relative_path_to_full fix filename a changing deploy path real world examples' do
        current_app_root = '/var/local/company/company.d/79'
        converter = AbsoluteFileConverter.new(['/var/local/company/company.d/[0-9]*/', "#{current_app_root}/"])

        expected_path = '/var/local/company/company.d/79/app/controllers/dashboard_controller.rb'
        key = '/var/local/company/company.d/78/app/controllers/dashboard_controller.rb'
        File.expects(:exist?).with('/var/local/company/company.d/[0-9]*/app/controllers/dashboard_controller.rb').returns(false)
        File.expects(:exist?).with(expected_path).returns(true)
        roots = ['/var/local/company/company.d/[0-9]*/', "#{current_app_root}/"]
        assert_equal expected_path, converter.convert(key)
        assert_equal expected_path, converter.convert(key)
      end
    end
  end
end
