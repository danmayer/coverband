# frozen_string_literal: true

require 'redis'

redis = Redis.new
script_id = redis.script(:load, <<~LUA)
  return { KEYS, ARGV }
LUA
puts redis.evalsha(script_id, ['key'], ['arg'])
