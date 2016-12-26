require "bundler/gem_tasks"

import 'test/benchmarks/benchmark.rake'

task :default => :test
require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  # exclude benchmark from the tests as the way it functions resets code coverage during executions
  #test.pattern = 'test/unit/*_test.rb'
  # using test files opposed to pattern as it outputs which files are run
  test.test_files = FileList['test/unit/*_test.rb']
  test.verbose = true
end
