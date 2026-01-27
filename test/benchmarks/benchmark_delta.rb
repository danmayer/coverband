require 'benchmark/ips'
require './lib/coverband'
require './lib/coverband/collectors/delta'

# Setup configuration
Coverband.configure do |config|
  config.root = "/app"
  # Some typical ignores
  config.ignore = [/config\/initializers\/.*/, /vendor\/.*/]
  config.logger = Logger.new('/dev/null')
end

# Reset Delta to pick up config
Coverband::Collectors::Delta.reset

# Generate data
project_dir = "/app"
ignored_dirs = ["/app/config/initializers", "/app/vendor"]
outside_dirs = ["/usr/lib/ruby", "/gem/gems"]
valid_dirs = ["/app/models", "/app/controllers"]

files = {}
10_000.times do |i|
  type = i % 4
  path = case type
         when 0 # Valid (In project, not ignored)
           "#{valid_dirs.sample}/file_#{i}.rb"
         when 1 # Ignored (In project, ignored)
           "#{ignored_dirs.sample}/file_#{i}.rb"
         when 2 # Outside project (Not in project)
           "#{outside_dirs.sample}/file_#{i}.rb"
         when 3 # Outside but looks like ignored if we checked regex only?
           "/tmp/vendor/file_#{i}.rb"
         end
  files[path] = [1, 1, 0, 1]
end

# Mock coverage class
class MockCoverage
  def initialize(results)
    @results = results
  end
  def results
    @results
  end
end

mock_coverage = MockCoverage.new(files)

puts "Benchmarking Delta.results with #{files.size} files"

Benchmark.ips do |x|
  x.report("Delta.results") do
    Coverband::Collectors::Delta.results(mock_coverage)
  end
end
