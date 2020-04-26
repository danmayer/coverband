require "coverage"

Coverage.start

require "./test/dog.rb"

puts Coverage.peek_result

puts Dog.new.bark

puts Coverage.peek_result

puts "done"
