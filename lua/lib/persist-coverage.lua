local hmset = function (key, dict)
  if next(dict) == nil then return nil end
  local bulk = {}
  for k, v in pairs(dict) do
    table.insert(bulk, k)
    table.insert(bulk, v)
  end
  return redis.call('HMSET', key, unpack(bulk))
end
local payload = cjson.decode(redis.call('get', (KEYS[1])))
local ttl = payload.ttl
local files_data = payload.files_data
redis.call('DEL', KEYS[1])
for _, file_data in ipairs(files_data) do

  local hash_key = file_data.hash_key
  local first_updated_at = file_data.meta.first_updated_at
  file_data.meta.first_updated_at = nil

  hmset(hash_key, file_data.meta)
  redis.call('HSETNX', hash_key, 'first_updated_at', first_updated_at)
  for line, coverage in pairs(file_data.coverage) do
    redis.call("HINCRBY", hash_key, line, coverage)
    if coverage > 0 then
      redis.call("HSET", hash_key, line .. "_last_posted", ARGV[1])
    end
  end
  if ttl and ttl ~= cjson.null then
    redis.call("EXPIRE", hash_key, ttl)
  end
end
