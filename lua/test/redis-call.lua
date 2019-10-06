redis = require 'redis'

-- If you have some different host/port change it here
local host = "127.0.0.1"
local port = 6379


client = redis.connect(host, port)

-- Workaround for absence of redis.call
redis.call = function(cmd, ...)
  local arg={...}
  local args_string = ''
  for i,v in ipairs(arg) do
    args_string = args_string .. ' ' .. v
  end
  cmd = string.lower(cmd)
  print(cmd .. args_string)
  --local result = assert(load('return client:'.. cmd ..'(...)'))(...)
  local result = assert(loadstring('return client:'.. cmd ..'(...)'))(...)

  -- The redis-lua library returns some values differently to how `redis.call` works inside redis.
  -- this makes the responses look like those from the builtin redis
  local response_lookup = {
    type = function() return { ["ok"]= result } end,
    sadd = function() return tonumber(result) end,
    zrange = function()
      if type(result) == "table" and type(result[1]) == "table" then
        -- Deal with WITHSCORES...
        local new_result = {}
        for k,v in pairs(result) do
          table.insert(new_result, v[1])
          table.insert(new_result, v[2])
        end
        return new_result;
      end

      return result;
    end,
    hgetall = function()
      local new_result = {}
      for key, value in pairs(result) do
        table.insert(new_result, key)
        table.insert(new_result, value)
      end
      return new_result
    end
  }

  if response_lookup[cmd] then
    return response_lookup[cmd]()
  end

  return result;
end
