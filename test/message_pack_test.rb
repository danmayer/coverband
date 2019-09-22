# frozen_string_literal: true

require File.expand_path('./test_helper', File.dirname(__FILE__))
require 'msgpack'

class MessagePackTest < Minitest::Test
  def test_message_pack
    redis = Redis.new
    obj = {
      'hello' => 'world'
    }
    obj = { key: 'coverband_hash_3_3.coverband_test.runtime../dog.rb.abcd',
            file: './dog.rb',
            file_hash: 'abcd',
            data: [0, nil, 1, 2],
            report_time: 1569063171,
            updated_time: 1569063171 }.transform_keys(&:to_s)
    packed = MessagePack.pack(obj)
    assert_equal(obj, MessagePack.unpack(packed))
    script = <<~LUA
      return cmsgpack.unpack(ARGV[1]).hello
    LUA
    result = redis.eval(script, argv: [packed])
    puts result
  end
end
