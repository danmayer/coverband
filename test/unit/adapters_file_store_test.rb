require File.expand_path('../test_helper', File.dirname(__FILE__))

class AdaptersFileStoreTest < Test::Unit::TestCase

  def setup
    @test_file_path = "/tmp/coverband_filestore_test_path.json"
    File.open(@test_file_path, 'w') { |f| f.write(test_data.to_json) }
    @store = Coverband::Adapters::FileStore.new(@test_file_path)
  end

  def test_covered_lines_for_file
    assert_equal @store.covered_lines_for_file('dog.rb')["1"],  1
    assert_equal @store.covered_lines_for_file('dog.rb')["2"],  2
  end

  def test_covered_lines_when_null
    assert_equal @store.covered_lines_for_file('none.rb'),  []
  end

  def test_covered_files
    assert_equal @store.covered_files(),  ['dog.rb']
  end

  def test_clear
    @store.clear!
    assert_equal false,  File.exist?(@test_file_path)
  end

  def test_save_report
    @store.save_report({"cat.rb" => {1 => 1}})
    assert_equal @store.covered_lines_for_file('cat.rb')["1"],  1
  end

  private

  def test_data
    {
      "dog.rb" => { 1 => 1, 2 => 2 },
    }
  end
end