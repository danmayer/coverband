### Internal Formats

If you are doing development having some documented examples of various internal data formats can be helpful...

The format we get from TracePoint, Coverage, Internal Representations, and Used by SimpleCov for reporting have traditionally varied a bit. We can document the differences in formats here.

#### Coverage

```
>> require 'coverage'
=> true
>> Coverage.start
=> nil
>> require './test/unit/dog.rb'
=> true
>>  5.times { Dog.new.bark }
=> 5
>> Coverage.peek_result
=> {"/Users/danmayer/projects/coverband/test/unit/dog.rb"=>[nil, nil, 1, 1, 5, nil, nil]}
```

#### SimpleCov

The same format, but relative paths.

```
{"test/unit/dog.rb"=>[1, 2, nil, nil, nil, nil, nil]}
```

#### Redis Store

We store relative path in Redis, the Redis hash stores line numbers -> count (as strings).

```
# Array
["test/unit/dog.rb"]

# Hash
{"test/unit/dog.rb"=>{"1"=>"1", "2"=>"2"}}
```

#### File Store

Similar format to redis store, but array with integer values

```
{"test/unit/dog.rb"=>{"1"=>1, "2"=>2}}
```
