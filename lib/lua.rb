# frozen_string_literal: true

require 'redis'

redis = Redis.new
script_id = redis.script(:load, <<~LUA)
  return redis.call("INCRBY", KEYS[1], ARGV[1])
LUA
puts redis.evalsha(script_id, ['josie'], ['8'])
