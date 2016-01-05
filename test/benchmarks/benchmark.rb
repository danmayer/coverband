#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'classifier-reborn', 'lib'))

require 'coverband'
require 'benchmark'
require 'redis'
require 'classifier-reborn'


Coverband.configure do |config|
  config.redis             = Redis.new
  config.root              = Dir.pwd
  config.startup_delay     = 0
  config.percentage        = 100.0
  config.logger            = $stdout
  config.verbose           = false
end

bm = Benchmark.measure do
  1000.times do
    Coverband::Base.instance.sample do
      b = ClassifierReborn::Bayes.new 'Interesting', 'Uninteresting'
      b.train_interesting "here are some good words. I hope you love them"
      b.train_uninteresting "here are some bad words, I hate you"
      b.classify "I hate bad words and you" # returns 'Uninteresting'
    end
  end
end


puts bm

