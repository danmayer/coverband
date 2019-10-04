local hash_values = redis.call('HGETALL', KEYS[1])
function remove(key)
  local val = hash_values[key]
  hash_values[key] = nil
  return val
end

redis.call('DEL', KEYS[1])
local first_updated_at = remove('first_updated_at')
local last_updated_at = remove('last_updated_at')
local file = remove('file')
local file_hash = remove('file_hash')
local ttl = remove('ttl')
local file_length = remove('file_length')
local hash_key = remove('hash_key')
redis.call('HMSET', hash_key, 'last_updated_at', last_updated_at, 'file', file, 'file_hash', file_hash, 'file_length', file_length)
redis.call('HSETNX', hash_key, 'first_updated_at', first_updated_at)
for line, coverage in pairs(hash_values) do
  if coverage  == '-1' then
    redis.call("HSET", hash_key, line, coverage)
  else
    redis.call("HINCRBY", hash_key, line, coverage)
  end
end
if ttl ~= '-1' then
  redis.call("EXPIRE", hash_key, ttl)
end
