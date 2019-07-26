# frozen_string_literal: true

require 'redis'

redis = Redis.new
script_id = redis.script(:load, <<~LUA)
  local first_updated_at = table.remove(ARGV, 1)
  local last_updated_at = table.remove(ARGV, 1)
  local file_hash = table.remove(ARGV, 1)
  local hash_key = table.remove(KEYS, 1)
  redis.call('HMSET', hash_key, 'last_updated_at', last_updated_at, 'file_hash', file_hash)
  redis.call('HSETNX', hash_key, 'first_updated_at', first_updated_at)
  for i, values in ipairs(KEYS) do
    if ARGV[i] == '-1' then
      redis.call("HSET", hash_key, KEYS[i], ARGV[i])
    else
      redis.call("HINCRBY", hash_key, KEYS[i], ARGV[i])
    end
  end
  return redis.call('HGETALL', hash_key)
LUA

debug_script_id = redis.script(:load, <<~LUA)
  local first_updated_at = table.remove(ARGV, 1)
  local last_updated_at = table.remove(ARGV, 1)
  local file_hash = table.remove(ARGV, 1)
  local hash_key = table.remove(KEYS, 1)
  redis.call('HMSET', hash_key, 'last_updated_at', last_updated_at, 'file_hash', file_hash)
  redis.call('HSETNX', hash_key, 'first_updated_at', first_updated_at)
  return { first_updated_at, last_updated_at, file_hash, hash_key }
LUA

puts redis.evalsha(script_id, %w[family josie noah wendy daddy gracie yvette], ['first_updated_at', 'last_updated_at', 'file_hash', 8, 1, 3, 5, 6, -1])
