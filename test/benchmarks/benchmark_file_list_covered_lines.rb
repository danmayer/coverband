# frozen_string_literal: true

require "benchmark/ips"
require "memory_profiler"

# Mock SourceFile to simulate the overhead of creating line objects
class MockSourceFile
  attr_reader :covered_lines_count

  def initialize(count)
    @covered_lines_count = count
  end

  def covered_lines
    # Simulate allocating an array of objects
    Array.new(@covered_lines_count) { Object.new }
  end
end

class FileList < Array
  def covered_lines_original
    return 0.0 if empty?
    map { |f| f.covered_lines.count }.inject(:+)
  end

  def covered_lines_optimized
    return 0.0 if empty?
    sum(&:covered_lines_count)
  end
end

# Generate data: 10,000 files with varying coverage
files = Array.new(10000) { |i| MockSourceFile.new(i % 100) }
file_list = FileList.new(files)

puts "---------------------------------------------------"
puts "Memory Profiling: FileList#covered_lines"

puts "\nOriginal (map.inject):"
report = MemoryProfiler.report { file_list.covered_lines_original }
puts "  Total allocated: #{report.total_allocated_memsize} bytes (#{report.total_allocated} objects)"

puts "\nOptimized (sum):"
report = MemoryProfiler.report { file_list.covered_lines_optimized }
puts "  Total allocated: #{report.total_allocated_memsize} bytes (#{report.total_allocated} objects)"

puts "\n---------------------------------------------------"
puts "Benchmark: FileList#covered_lines"

Benchmark.ips do |x|
  x.report("map.inject") { file_list.covered_lines_original }
  x.report("sum") { file_list.covered_lines_optimized }
  x.compare!
end
