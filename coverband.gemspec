# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'coverband/version'

Gem::Specification.new do |spec|
  spec.name          = "coverband"
  spec.version       = Coverband::VERSION
  spec.authors       = ["Dan Mayer"]
  spec.email         = ["dan@mayerdan.com"]
  spec.description   = %q{Rack middleware to help measure production code coverage}
  spec.summary       = %q{Rack middleware to help measure production code coverage}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "mocha", "~> 0.14.0"
  spec.add_development_dependency "rack"
  spec.add_development_dependency "coverband_ext", "~> 1.1"
  spec.add_development_dependency "test-unit"
  spec.add_runtime_dependency "simplecov"
  spec.add_runtime_dependency "json"
  spec.add_runtime_dependency "redis"
end
