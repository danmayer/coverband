#!/usr/bin/env ruby

# This is a small script to illustrate how previous results get wiped out by forking
# this has implications of forking processes like Resque...
# this in the end would cause coverage.array_diff
# with previous results to add NEGATIVE code hits to the stored Coverage
# which in turn causes all sorts of crazy issues.
#
# ruby test/benchmarks/coverage_fork.rb
# in parent before fork
# {"/Users/danmayer/projects/coverband/test/dog.rb"=>[nil, nil, 1, 1, 2, nil, nil]}
# in child after fork
# {"/Users/danmayer/projects/coverband/test/dog.rb"=>[nil, nil, 0, 0, 0, nil, nil]}
# now triggering hits
# {"/Users/danmayer/projects/coverband/test/dog.rb"=>[nil, nil, 0, 0, 3, nil, nil]}
#
# I believe this might be related to CoW and GC... not sure
# http://patshaughnessy.net/2012/3/23/why-you-should-be-excited-about-garbage-collection-in-ruby-2-0
#
# NOTE: That the child now has 0 hits where previously method definitions had 1
# this causes all sorts of bad things to happen.
require 'coverage'
Coverage.start
load './test/dog.rb'
Dog.new.bark
Dog.new.bark
puts 'in parent before fork'
puts Coverage.peek_result
fork do
  puts 'in child after fork'
  puts Coverage.peek_result
  puts 'now triggering hits'
  Dog.new.bark
  Dog.new.bark
  Dog.new.bark
  puts Coverage.peek_result
end
