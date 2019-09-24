local first_updated_at = table.remove(ARGV, 1)
local last_updated_at = table.remove(ARGV, 1)
local file = table.remove(ARGV, 1)
local file_hash = table.remove(ARGV, 1)
local ttl = table.remove(ARGV, 1)
local file_length = table.remove(ARGV, 1)
local hash_key = table.remove(KEYS, 1)
redis.call('HMSET', hash_key, 'last_updated_at', last_updated_at, 'file', file, 'file_hash', file_hash, 'file_length', file_length)
redis.call('HSETNX', hash_key, 'first_updated_at', first_updated_at)
for i, key in ipairs(KEYS) do
  if ARGV[i] == '-1' then
    redis.call("HSET", hash_key, key, ARGV[i])
  else
    redis.call("HINCRBY", hash_key, key, ARGV[i])
  end
end
if ttl ~= '-1' then
  redis.call("EXPIRE", hash_key, ttl)
end
