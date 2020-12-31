# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class AdaptersNullStoreTest < Minitest::Test
  def test_covered_lines_when_no_file
    @store = Coverband::Adapters::NullStore.new("")
    expected = {}
    assert_equal expected, @store.coverage
  end

  describe "Coverband::Adapters::NullStore" do
    def setup
      super
      @store = Coverband::Adapters::NullStore.new(@test_file_path)
    end

    def test_coverage
      assert_equal @store.coverage, {}
    end

    def test_covered_lines_when_null
      assert_nil @store.coverage["none.rb"]
    end

    def test_covered_files
      assert_equal @store.covered_files.include?("dog.rb"), false
    end

    def test_clear
      assert_nil @store.clear!
    end

    def test_save_report
      @store.send(:save_report, "cat.rb" => [0, 1])
      assert_equal @store.coverage, {}
    end
  end
end
