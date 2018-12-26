# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'coverband/version'

Gem::Specification.new do |spec|
  spec.name          = 'coverband'
  spec.version       = Coverband::VERSION
  spec.authors       = ['Dan Mayer', 'Karl Baum']
  spec.email         = ['dan@mayerdan.com']
  spec.description   = 'Rack middleware to help measure production code usage (LOC runtime usage)'
  spec.summary       = 'Rack middleware to help measure production code usage (LOC runtime usage)'
  spec.homepage      = 'https://github.com/danmayer/coverband'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split("\n").reject { |f| f.start_with?('docs') }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # to test support for sdk 1, uncomment this line
  # spec.add_development_dependency 'aws-sdk', '~> 1'
  # to test sdk 2 use this one
  spec.add_development_dependency 'aws-sdk', '~> 2'
  spec.add_development_dependency 'benchmark-ips'
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'm'
  spec.add_development_dependency 'memory_profiler'
  spec.add_development_dependency 'mocha', '~> 1.7.0'
  spec.add_development_dependency 'rack'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'test-unit'

  # used for benchmarking and tests
  spec.add_development_dependency 'classifier-reborn'
  # add when debugging
  # require 'byebug'; byebug
  spec.add_development_dependency 'pry-byebug'

  # TODO: Remove when other production adapters exist
  # because the default configuration of redis store, we really do require
  # redis now. I was reluctant to add this, but until we offer another production
  # quality adapter, I think this is more honest about requirements and reduces confusion
  # without this there was a race condition on calling coverband configure before redis was loaded
  spec.add_runtime_dependency 'redis'
  # TODO: make an optional dependency for simplecov reports
  # also likely should just require simplecov-html not the whole lib
  # I tried this but it was harder than I thought
  spec.add_runtime_dependency 'simplecov', '> 0.11.1'
end
