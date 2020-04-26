# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

module Coverband
  module Utils
    class FileHasherTest < Minitest::Test
      def test_hash_same_file
        refute_nil FileHasher.hash("./test/dog.rb")
        assert_equal(FileHasher.hash("./test/dog.rb"), FileHasher.hash("./test/dog.rb"))
        assert_equal(FileHasher.hash(File.expand_path("./test/dog.rb")), FileHasher.hash("./test/dog.rb"))
      end

      def test_hash_different_files
        refute_equal(FileHasher.hash("./test/dog.rb"), FileHasher.hash("./lib/coverband.rb"))
      end

      def test_hash_file_not_exists
        assert_nil(FileHasher.hash("./made_up_file.py"))
      end
    end
  end
end
