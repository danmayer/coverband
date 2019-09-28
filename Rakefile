# frozen_string_literal: true

require 'bundler/gem_tasks'
import 'test/benchmarks/benchmark.rake'
require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %i[test]

task 'test:all': %i[rubocop test forked_tests benchmarks:memory benchmarks]

task :test
require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  # exclude benchmark from the tests as the way it functions resets code coverage during executions
  # test.pattern = 'test/unit/*_test.rb'
  # using test files opposed to pattern as it outputs which files are run
  test.test_files = FileList['test/integration/**/*_test.rb', 'test/coverband/**/*_test.rb']
  test.verbose = true
end

Rake::TestTask.new(:forked_tests) do |test|
  test.libs << 'lib' << 'test'
  test.test_files = FileList['test/forked/**/*_test.rb']
  test.verbose = true
end

desc 'load irb with this gem'
task :console do
  puts 'running console'
  exec 'bundle console'
end

# This is really just for testing and development because without configuration
# Coverband can't do much
desc 'start webserver'
task :server do
  exec 'rackup -I lib'
end

desc 'publish gem with 2 factor auth, reminder how'
task :publish_gem do
  exec 'gem push pkg/coverband-4.2.3.XXX.gem'
end
