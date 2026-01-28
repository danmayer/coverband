# frozen_string_literal: true

require "benchmark/ips"
require "set"

# Simulate the AbstractTracker class and the unused_keys method
class MockTracker
  def unused_keys(all_keys, used_keys_hash)
    recently_used_keys = used_keys_hash.keys
    all_keys.reject { |k| recently_used_keys.include?(k.to_s) }
  end

  def unused_keys_set(all_keys, used_keys_hash)
    recently_used_keys = used_keys_hash.keys.to_set
    all_keys.reject { |k| recently_used_keys.include?(k.to_s) }
  end

  def unused_keys_hash(all_keys, used_keys_hash)
    recently_used_keys = used_keys_hash
    all_keys.reject { |k| recently_used_keys.key?(k.to_s) }
  end
end

# Setup data
# We want a significant number of keys to see the O(N*M) vs O(N) difference
N_ALL_KEYS = 10_000
N_USED_KEYS = 5_000

puts "Generating data: #{N_ALL_KEYS} all_keys, #{N_USED_KEYS} used_keys..."
all_keys = N_ALL_KEYS.times.map { |i| "key_#{i}" }
# Shuffle used keys to make it interesting, and make sure they are a subset
used_keys_list = all_keys.sample(N_USED_KEYS)
used_keys_hash = used_keys_list.each_with_object({}) { |k, h| h[k] = 1 }

tracker = MockTracker.new

puts "Benchmarking..."
Benchmark.ips do |x|
  x.report("original") do
    tracker.unused_keys(all_keys, used_keys_hash)
  end

  x.report("optimized_set") do
    tracker.unused_keys_set(all_keys, used_keys_hash)
  end

  x.report("optimized_hash") do
    tracker.unused_keys_hash(all_keys, used_keys_hash)
  end

  x.compare!
end
