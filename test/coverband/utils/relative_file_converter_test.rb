# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

module Coverband
  module Utils
    class RelativeFileConverterTest < ::Minitest::Test
      def test_convert
        converter = RelativeFileConverter.new(["/bar/tmp/"])
        assert_equal("./gracie.rb", converter.convert("/bar/tmp/gracie.rb"))
      end

      def test_convert_without_leading_forward_slash
        converter = RelativeFileConverter.new(["/foo/bar"])
        assert_equal("./file.rb", converter.convert("/foo/bar/file.rb"))
      end

      def test_multiple_roots
        converter = RelativeFileConverter.new(["/bar/tmp/", "/foo/bar/"])
        assert_equal("./josie.rb", converter.convert("/foo/bar/josie.rb"))
      end

      def test_no_match
        converter = RelativeFileConverter.new(["/bar/tmp/", "/foo/bar/"])
        assert_equal("/foo/josie.rb", converter.convert("/foo/josie.rb"))
      end

      def test_middle_path_match
        converter = RelativeFileConverter.new(["/bar/tmp/", "/foo/bar/"])
        assert_equal("/tmp/foo/bar/josie.rb", converter.convert("/tmp/foo/bar/josie.rb"))
      end

      def test_already_relative_file
        converter = RelativeFileConverter.new(["/bar/tmp/", "/foo/bar/"])
        assert_equal("./foo/bar/josie.rb", converter.convert("./foo/bar/josie.rb"))
      end

      def test_symlinked_root
        Dir.mktmpdir do |dir|
          real_dir = File.join(dir, "real")
          sym_dir = File.join(dir, "sym")
          Dir.mkdir(real_dir)
          FileUtils.touch(File.join(real_dir, "file.rb"))
          FileUtils.ln_s(real_dir, sym_dir)

          # Root configured as symlink
          converter = RelativeFileConverter.new([sym_dir])
          # File reported as real path
          file_path = File.join(real_dir, "file.rb")

          # Should convert to relative path
          assert_equal "./file.rb", converter.convert(file_path)

          # Root configured as real path
          converter = RelativeFileConverter.new([real_dir])
          # File reported as symlink path
          file_path = File.join(sym_dir, "file.rb")

          # Should convert to relative path
          assert_equal "./file.rb", converter.convert(file_path)
        end
      end
    end
  end
end
