# frozen_string_literal: true

require "benchmark/ips"
require "memory_profiler"

# Mock SourceFile
class MockSourceFile
  attr_reader :first_updated_at

  def initialize(first_updated_at)
    @first_updated_at = first_updated_at
  end
end

class FileList < Array
  def first_seen_at_current
    filter_map { |f|
      val = f.first_updated_at
      val unless val.is_a?(String)
    }.min
  end

  def first_seen_at_original
    map(&:first_updated_at).reject { |el| el.is_a?(String) }.min
  end

  def first_seen_at_each
    min = nil
    each do |f|
      val = f.first_updated_at
      next if val.is_a?(String)
      min = val if min.nil? || val < min
    end
    min
  end
end

# Generate data: 10,000 files
files_mixed = Array.new(10000) { |i|
  val = (i % 5 == 0) ? "not available" : (Time.now - i)
  MockSourceFile.new(val)
}
list_mixed = FileList.new(files_mixed)

puts "---------------------------------------------------"
puts "Memory Profiling: FileList#first_seen_at"

puts "\nOriginal (map+reject):"
report = MemoryProfiler.report { list_mixed.first_seen_at_original }
puts "  Total allocated: #{report.total_allocated_memsize} bytes (#{report.total_allocated} objects)"

puts "\nCurrent (filter_map):"
report = MemoryProfiler.report { list_mixed.first_seen_at_current }
puts "  Total allocated: #{report.total_allocated_memsize} bytes (#{report.total_allocated} objects)"

puts "\nOptimized (each):"
report = MemoryProfiler.report { list_mixed.first_seen_at_each }
puts "  Total allocated: #{report.total_allocated_memsize} bytes (#{report.total_allocated} objects)"
