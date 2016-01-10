require "bundler/gem_tasks"
require 'coverband_ext' if ENV['C_EXT']

import 'test/benchmarks/benchmark.rake'

task :default => :test
require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end
