# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

module Coverband
  class MemoryCacheStoreTest < Test::Unit::TestCase
    def setup
      Adapters::MemoryCacheStore.clear!
      @redis = Redis.new
      @store = Coverband::Adapters::RedisStore.new(@redis)
      @store.clear!
      @memory_store = Adapters::MemoryCacheStore.new(@store)
    end

    test 'it passes data into store' do
      data = {
        'file1' => { 1 => 0, 2 => 1, 3 => 0 },
        'file2' => { 1 => 5, 2 => 2 }
      }
      @store.expects(:save_report).with data
      @memory_store.save_report data
    end


    test 'it filters coverage with same exact data' do
      data = {
        'file1' => { 1 => 0, 2 => 1, 3 => 0 },
        'file2' => { 1 => 5, 2 => 2 }
      }
      @store.expects(:save_report).once.with data
      2.times { @memory_store.save_report data }
    end

    
    test 'it filters coverage for files with same exact data' do
 
      report_first_request = {
        'file1' => { 1 => 0, 2 => 1, 3 => 0 },
        'file2' => { 1 => 5, 2 => 2, 3 => 0 }
      }

      report_second_request = {
        'file1' => { 1 => 0, 2 => 1, 3 => 0 },
        'file2' => { 1 => 5, 2 => 3, 3 => 1 }
      }
      @store.expects(:save_report).with({
        'file1' => { 1 => 0, 2 => 1, 3 => 0 },
        'file2' => { 1 => 5, 2 => 2, 3 => 0 }
      })
      @store.expects(:save_report).with({
        'file2' => { 1 => 5, 2 => 3, 3 => 1 }
      })
      @memory_store.save_report(report_first_request)
      @memory_store.save_report(report_second_request)
    end

    test 'it filters coverage for files with the same lines being hit' do

      report_first_request = {
        'file1' => { 1 => 0, 2 => 1, 3 => 0 },
        'file2' => { 1 => 5, 2 => 2 }
      }

      report_second_request = {
        'file1' => { 1 => 0, 2 => 2, 3 => 0 },
        'file2' => { 1 => 6, 2 => 3 }
      }
      @store.expects(:save_report).once.with report_first_request
      @memory_store.save_report(report_first_request)
      @memory_store.save_report(report_second_request)
    end
  end
end
