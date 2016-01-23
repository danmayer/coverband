require File.expand_path('../test_helper', File.dirname(__FILE__))
require 'pry-byebug'

class MemoryCacheStoreTest < Test::Unit::TestCase

  def setup
    @cache_store = mock('cache_store')
    @memory_cache_store = MemoryCacheStore.new(@cache_store)
  end


  test 'it passes data into cache store' do
    data = {
      'file1' => [ 3, 5 ],
      'file2' => [1, 2]
    }
    @cache_store.expects(:store_report).with data
    @memory_cache_store.store_report data
  end


end
