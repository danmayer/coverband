require File.expand_path('../test_helper', File.dirname(__FILE__))

module Coverband
  class MemoryCacheStoreTest < Test::Unit::TestCase

    def setup
      MemoryCacheStore.reset!
      @store = mock('store')
      @memory_store = MemoryCacheStore.new(@store)
    end


    test 'it passes data into store' do
      data = {
        'file1' => [ 3, 5 ],
        'file2' => [1, 2]
      }
      @store.expects(:store_report).with data
      @store.expects(:covered_lines_for_file).with('file1').returns []
      @store.expects(:covered_lines_for_file).with('file2').returns []
      @memory_store.store_report data
    end

    test 'it passes data into store only once' do
      data = {
        'file1' => [ 3, 5 ],
        'file2' => [1, 2]
      }
      @store.expects(:store_report).once.with data
      @store.expects(:covered_lines_for_file).with('file1').returns []
      @store.expects(:covered_lines_for_file).with('file2').returns []
      2.times { @memory_store.store_report data }
    end

    test 'it only passes files and lines we have not hit yet' do
      first_data = {
        'file1' => [ 3, 5 ],
        'file2' => [1, 2]
      }
      second_data = {
        'file1' => [ 3, 5, 10 ],
        'file2' => [1, 2]
      }
      @store.expects(:covered_lines_for_file).with('file1').returns []
      @store.expects(:covered_lines_for_file).with('file2').returns []
      @store.expects(:store_report).once.with first_data
      @store.expects(:store_report).once.with(
        'file1' => [10]
      )
      @memory_store.store_report first_data
      @memory_store.store_report second_data
    end

  end
end
