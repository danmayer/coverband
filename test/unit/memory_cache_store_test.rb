require File.expand_path('../test_helper', File.dirname(__FILE__))
require 'pry-byebug'

class MemoryCacheStoreTest < Test::Unit::TestCase

  def setup
    @store = mock('store')
    @memory_store = MemoryCacheStore.new(@store)
  end


  test 'it passes data into store' do
    data = {
      'file1' => [ 3, 5 ],
      'file2' => [1, 2]
    }
    @store.expects(:store_report).with data
    @memory_store.store_report data
  end

  test 'it passes data into store only once' do
    data = {
      'file1' => [ 3, 5 ],
      'file2' => [1, 2]
    }
    @store.expects(:store_report).once.with data
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
    @store.expects(:store_report).once.with first_data
    @store.expects(:store_report).once.with(
      'file1' => [10]
    )
    @memory_store.store_report first_data
    @memory_store.store_report second_data
  end

end
