# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'coverband/version'

Gem::Specification.new do |spec|
  spec.name          = "coverband"
  spec.version       = Coverband::VERSION
  spec.authors       = ["Dan Mayer"]
  spec.email         = ["dan@mayerdan.com"]
  spec.description   = %q{Rack middleware to help measure production code usage (LOC runtime usage)}
  spec.summary       = %q{Rack middleware to help measure production code usage (LOC runtime usage)}
  spec.homepage      = "https://github.com/danmayer/coverband"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "mocha", "~> 0.14.0"
  spec.add_development_dependency "rack"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "test-unit"
  spec.add_development_dependency 'sinatra'
  spec.add_development_dependency 'classifier-reborn'
  spec.add_development_dependency 'aws-sdk', '~> 2'
  spec.add_runtime_dependency "simplecov", '~> 0.11.1'
  spec.add_runtime_dependency "json"
  # TODO make redis optional dependancy as we add additional adapters
  spec.add_runtime_dependency "redis"
end
