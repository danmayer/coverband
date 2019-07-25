# frozen_string_literal: true

require 'redis'

redis = Redis.new
script_id = redis.script(:load, <<~LUA)
  for i, key in ipairs(KEYS) do
    redis.call("INCRBY", KEYS[i], ARGV[i])
  end
LUA
puts redis.evalsha(script_id, %w[josie noah wendy gracie], ['8', 1, 3, 5])
