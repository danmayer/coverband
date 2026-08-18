# frozen_string_literal: true

require "bundler/gem_tasks"
import "test/benchmarks/benchmark.rake"
require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test]

task "test:all": %i[test test:javascript forked_tests benchmarks:memory benchmarks]

task :test
require "rake/testtask"
Rake::TestTask.new(:test) do |test|
  test.libs << "lib" << "test"
  # exclude benchmark from the tests as the way it functions resets code coverage during executions
  # test.pattern = 'test/unit/*_test.rb'
  # using test files opposed to pattern as it outputs which files are run
  test.test_files = FileList["test/integration/**/*_test.rb", "test/coverband/**/*_test.rb"]
  test.verbose = true
end

###
# Solid Cache brings a Rails engine with it, which changes how the rest of the
# suite behaves in the same process. It gets its own task and its own process.
###
desc "run the Solid Cache backed adapter tests (SQLite, needs solid_cache)"
task :"test:solid_cache" do
  # BUNDLE_WITH opts the optional group onto the load path for this run only
  sh({"COVERBAND_SOLID_CACHE" => "true", "BUNDLE_WITH" => "solid_cache"},
    "bundle exec ruby -Ilib -Itest test/coverband/adapters/solid_cache_store_test.rb")
end

desc "run the web report's javascript unit tests (node --test)"
task :"test:javascript" do
  # Pass expanded file paths rather than the bare directory: node's
  # directory-argument handling for --test is inconsistent across versions
  # (Node 22 fails to find test/javascript/ as a directory in some CI images).
  sh "node --test #{FileList["test/javascript/*.test.mjs"].join(" ")}"
end

Rake::TestTask.new(:forked_tests) do |test|
  if RUBY_PLATFORM == "java"
    puts "forked tests not supported on JRuby"
  else
    test.libs << "lib" << "test"
    test.test_files = FileList["test/forked/**/*_test.rb"]
    test.verbose = true
  end
end

desc "load irb with this gem"
task :console do
  puts "running console"
  exec "bundle console"
end

# This is really just for testing and development because without configuration
# Coverband can't do much
desc "start webserver"
task :server do
  exec "rackup -I lib"
end

desc "publish gem with 2 factor auth, reminder how"
task :publish_gem do
  exec "gem push pkg/coverband-4.2.3.XXX.gem"
end
