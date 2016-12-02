require File.expand_path('../test_helper', File.dirname(__FILE__))

module Coverband
  class MemoryCacheStoreTest < Test::Unit::TestCase

    def setup
      MemoryCacheStore.reset!
      @store = mock('store')
      @memory_store = MemoryCacheStore.new(@store)
    end

    def data
      {
        'file1' => { 3 => 1, 5 => 2 },
        'file2' => { 1 => 1, 2 => 1 }
      }
    end

    test 'it passes data into store' do
      @store.expects(:store_report).with data
      @store.expects(:covered_lines_for_file).with('file1').returns []
      @store.expects(:covered_lines_for_file).with('file2').returns []
      @memory_store.store_report data
    end

    test 'it passes data into store only once' do
      @store.expects(:store_report).once.with data
      @store.expects(:covered_lines_for_file).with('file1').returns []
      @store.expects(:covered_lines_for_file).with('file2').returns []
      2.times { @memory_store.store_report data }
    end

    test 'it only passes files and lines we have not hit yet' do
      second_data = {
        'file1' => { 3 => 1, 5 => 1, 10 => 1 },
        'file2' => { 1 => 1, 2 => 1 }
      }
      @store.expects(:covered_lines_for_file).with('file1').returns []
      @store.expects(:covered_lines_for_file).with('file2').returns []
      @store.expects(:store_report).once.with data
      @store.expects(:store_report).once.with(
        'file1' => { 10 => 1 }
      )
      @memory_store.store_report data
      @memory_store.store_report second_data
    end

    test 'it initializes cache with what is in store' do
      @store.expects(:covered_lines_for_file).with('file1').returns [3,5]
      @store.expects(:covered_lines_for_file).with('file2').returns [2]
      @store.expects(:store_report).with('file2' => { 1 => 1 })
      @memory_store.store_report data
    end

  end

end
