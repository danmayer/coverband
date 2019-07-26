# frozen_string_literal: true

require 'redis'

redis = Redis.new
script_id = redis.script(:load, <<~LUA)
  for i, values in ipairs(ARGV) do
    if ARGV[i] == '-1' then
      redis.call("HSET", KEYS[1], KEYS[i+1], ARGV[i])
    else
      redis.call("HINCRBY", KEYS[1], KEYS[i+1], ARGV[i])
    end
  end
  return redis.call('HGETALL', KEYS[1])
LUA
puts redis.evalsha(script_id, %w[family josie noah wendy daddy gracie yvette], [8, 1, 3, 5, 6, -1])
