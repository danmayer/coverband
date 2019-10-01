local call_redis_script = require "./lua/test/harness";

describe("incr-and-stor", function()

  -- Flush the database before running the tests
  before_each(function()
    redis.call('FLUSHDB')
  end)

  it("should add single items", function()
    local args = { 1569453853, 1569453853, "./dog.rb", "abcd", '-1', 3, 0, 1, 2 }
    local keys = {"coverband_hash_3_3.coverband_test.runtime../dog.rb.abcd", 0, 1, 2 }
    call_redis_script('persist-coverage.lua',  keys ,  args );
    results = redis.call('HGETALL', "coverband_hash_3_3.coverband_test.runtime../dog.rb.abcd")
    assert.are.same({
      ["0"] = "0",
      ["1"] = "1",
      ["2"] = "2",
      file = "./dog.rb",
      file_hash = "abcd",
      file_length = "3",
      first_updated_at = "1569453853",
      last_updated_at = "1569453853"
    }, results)
  end)
end)
