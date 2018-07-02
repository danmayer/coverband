require File.expand_path('../test_helper', File.dirname(__FILE__))

module Coverband
  class MemoryCacheStoreTest < Test::Unit::TestCase

    def setup
      Adapters::MemoryCacheStore.reset!
      @store = mock('store')
      @memory_store = Adapters::MemoryCacheStore.new(@store)
    end

    def data
      {
        'file1' => { 3 => 1, 5 => 2 },
        'file2' => { 1 => 1, 2 => 1 }
      }
    end

    test 'it passes data into store' do
      @store.expects(:save_report).with data
      @store.expects(:covered_lines_for_file).with('file1').returns []
      @store.expects(:covered_lines_for_file).with('file2').returns []
      @memory_store.save_report data
    end

    test 'it passes data into store only once' do
      @store.expects(:save_report).once.with data
      @store.expects(:covered_lines_for_file).with('file1').returns []
      @store.expects(:covered_lines_for_file).with('file2').returns []
      2.times { @memory_store.save_report data }
    end

    test 'it only passes files and lines we have not hit yet' do
      second_data = {
        'file1' => { 3 => 1, 5 => 1, 10 => 1 },
        'file2' => { 1 => 1, 2 => 1 }
      }
      @store.expects(:covered_lines_for_file).with('file1').returns []
      @store.expects(:covered_lines_for_file).with('file2').returns []
      @store.expects(:save_report).once.with data
      @store.expects(:save_report).once.with(
        'file1' => { 10 => 1 }
      )
      @memory_store.save_report data
      @memory_store.save_report second_data
    end

    test 'it initializes cache with what is in store' do
      @store.expects(:covered_lines_for_file).with('file1').returns [3,5]
      @store.expects(:covered_lines_for_file).with('file2').returns [2]
      @store.expects(:save_report).with('file2' => { 1 => 1 })
      @memory_store.save_report data
    end

    test 'it doesn\'t pass data into store for one call' do
      file_data = {
        'file0' => { 1 => 1, 5 => 1 }
      }

      @memory_store.instance_variable_set('@max_caching', 3)
      @store.expects(:covered_lines_for_file).with('file0').returns []
      @store.expects(:save_report).times(0)
      @memory_store.save_report({ 'file0' => file_data['file0'] })
    end

    test 'it doesn\'t pass data into store for two calls' do
      file_data = {
        'file0' => { 1 => 1, 5 => 1 },
        'file1' => { 4 => 1, 5 => 1 }
      }

      @memory_store.instance_variable_set('@max_caching', 3)
      @store.expects(:covered_lines_for_file).with('file0').returns []
      @store.expects(:covered_lines_for_file).with('file1').returns []
      @store.expects(:save_report).times(0)
      @memory_store.save_report({ 'file0' => file_data['file0'] })
      @memory_store.save_report({ 'file1' => file_data['file1'] })
    end

    test 'it passes data into store for three calls' do
      file_data = {
        'file0' => { 1 => 1, 5 => 1 },
        'file1' => { 4 => 1, 5 => 1 },
        'file2' => { 6 => 1 }
      }

      @memory_store.instance_variable_set('@max_caching', 3)
      # This represents the state of the persistent storage
      @store.expects(:covered_lines_for_file).with('file0').returns []
      @store.expects(:covered_lines_for_file).with('file1').returns []
      @store.expects(:covered_lines_for_file).with('file2').returns []
      @store.expects(:save_report).once.with(file_data)
      @memory_store.save_report({ 'file0' => file_data['file0'] })
      @memory_store.save_report({ 'file1' => file_data['file1'] })
      @memory_store.save_report({ 'file2' => file_data['file2'] })
    end

    test 'it passes data into store for three calls - same file' do
      iter0 = { 1 => 1, 5 => 1 }
      iter1 = { 4 => 1, 5 => 1 }
      iter2 = { 1 => 1, 6 => 1 }

      @memory_store.instance_variable_set('@max_caching', 3)
      # This represents the state of the persistent storage
      @store.expects(:covered_lines_for_file).with('file0').returns []
      @store.expects(:save_report).once.with({ 'file0' => { 1 => 1, 5 => 1, 4 => 1, 6 => 1 } })
      @memory_store.save_report({ 'file0' => iter0 })
      @memory_store.save_report({ 'file0' => iter1 })
      @memory_store.save_report({ 'file0' => iter2 })
    end

    test 'it passes data into store for three calls - data in persistent storage' do
      iter0 = { 1 => 1, 5 => 1 }
      iter1 = { 4 => 1, 5 => 1 }
      iter2 = { 1 => 1, 6 => 1 }

      @memory_store.instance_variable_set('@max_caching', 3)
      # This represents the state of the persistent storage
      @store.expects(:covered_lines_for_file).with('file0').returns [1, 5]
      @store.expects(:save_report).once.with({ 'file0' => { 4 => 1, 6 => 1 } })
      @memory_store.save_report({ 'file0' => iter0 })
      @memory_store.save_report({ 'file0' => iter1 })
      @memory_store.save_report({ 'file0' => iter2 })
    end

  end

end
