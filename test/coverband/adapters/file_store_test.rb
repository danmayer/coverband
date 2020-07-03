# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class AdaptersFileStoreTest < Minitest::Test
  def test_covered_lines_when_no_file
    @store = Coverband::Adapters::FileStore.new("")
    expected = {}
    assert_equal expected, @store.coverage
  end

  describe "Coverband::Adapters::FileStore with file" do
    def setup
      super
      @test_file_path = "/tmp/coverband_filestore_test_path.json"
      previous_file_path = "#{@test_file_path}.#{::Process.pid}"
      `rm #{@test_file_path}` if File.exist?(@test_file_path)
      `rm #{previous_file_path}` if File.exist?(previous_file_path)
      File.open(previous_file_path, "w") { |f| f.write(test_data.to_json) }
      @store = Coverband::Adapters::FileStore.new(@test_file_path)
    end

    def test_coverage
      assert_equal @store.coverage["dog.rb"]["data"][0], 1
      assert_equal @store.coverage["dog.rb"]["data"][1], 2
    end

    def test_covered_lines_when_null
      assert_nil @store.coverage["none.rb"]
    end

    def test_covered_files
      assert @store.covered_files.include?("dog.rb")
    end

    def test_clear
      @store.clear!
      assert_equal false, File.exist?(@test_file_path)
    end

    def test_save_report
      mock_file_hash
      @store.send(:save_report, "cat.rb" => [0, 1])
      assert_equal @store.coverage["cat.rb"]["data"][1], 1
      assert @store.size > 1
    end

    def test_data
      {
        "dog.rb" => {"data" => [1, 2, nil],
                     "file_hash" => "abcd",
                     "first_updated_at" => 1541968729,
                     "last_updated_at" => 1541968729}
      }
    end
  end
end
