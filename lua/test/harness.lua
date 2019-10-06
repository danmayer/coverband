require './lua/test/bootstrap'


KEYS = {}
ARGV = {}


function call_redis_script(script, keys, argv)
  -- This may not be strictly necessary
  for k,v in pairs(ARGV) do ARGV[k] = nil end
  for k,v in pairs(KEYS) do KEYS[k] = nil end

  for k,v in pairs(keys) do table.insert(KEYS, v) end
  for k,v in pairs(argv) do table.insert(ARGV, v)  end

  return dofile('./lua/lib/' .. script)
end

return call_redis_script;
