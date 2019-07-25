# frozen_string_literal: true

require 'redis'

redis = Redis.new
script_id = redis.script(:load, <<~LUA)
  for i, values in ipairs(ARGV) do
    redis.call("HINCRBY", KEYS[1], KEYS[i+1], ARGV[i])
  end
LUA
puts redis.evalsha(script_id, %w[family josie noah wendy daddy gracie], [8, 1, 3, 5, 6])
