local call_redis_script = require "./lua/test/harness";

describe("incr-and-stor", function()
  local function hgetall(hash_key)
    local flat_map = redis.call('HGETALL', hash_key)
    local result = {}
    for i = 1, #flat_map, 2 do
      result[flat_map[i]] = flat_map[i + 1]
    end
    return result
  end



  local function clean_redis() 
    redis.call('DEL', 'coverband_hash_3_3.coverband_test.runtime../dog.rb.abcd')
  end

  before_each(function()
    clean_redis()
  end)

  after_each(function()
    clean_redis()
  end)

  it("should add single items", function()
    local first_updated_at = "1569453853"
    local last_updated_at = first_updated_at

    local key = 'hash_key'
    redis.call( 'hmset', key, 
    'hash_key', "coverband_hash_3_3.coverband_test.runtime../dog.rb.abcd",
    'first_updated_at', 
    first_updated_at, 
    'last_updated_at', 
    last_updated_at, 
    'file', "./dog.rb", 
    'file_hash', 'abcd', 
    'ttl', '-1', 
    'file_length', 3, 
    0, 0, 
    1, 1, 
    2, 2)



    call_redis_script('persist-coverage.lua',  { key },  {});
    local results = hgetall("coverband_hash_3_3.coverband_test.runtime../dog.rb.abcd")
    assert.are.same({
      ["0"] = "0",
      ["1"] = "1",
      ["2"] = "2",
      file = "./dog.rb",
      file_hash = "abcd",
      file_length = "3",
      first_updated_at = first_updated_at ,
      last_updated_at = last_updated_at
    }, results)
    
    assert.is_false(false, redis.call('exists', key))

    last_updated_at = "1569453953"
    redis.call( 'hmset', key, 
    'hash_key', "coverband_hash_3_3.coverband_test.runtime../dog.rb.abcd",
    'first_updated_at', first_updated_at, 
    'last_updated_at', last_updated_at, 
    'file', "./dog.rb", 
    'file_hash', 'abcd', 
    'ttl', '-1', 
    'file_length', 3, 
    0, 1, 
    1, 1, 
    2, 1)

    call_redis_script('persist-coverage.lua',  { key },  {} );
    results = hgetall("coverband_hash_3_3.coverband_test.runtime../dog.rb.abcd")
    assert.are.same({
      ["0"] = "1",
      ["1"] = "2",
      ["2"] = "3",
      file = "./dog.rb",
      file_hash = "abcd",
      file_length = "3",
      first_updated_at = first_updated_at,
      last_updated_at = last_updated_at 
    }, results)

    assert.is_false(false, redis.call('exists', key))
  end)
end)
