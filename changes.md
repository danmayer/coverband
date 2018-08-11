# Future Roadmap

### Coverband 3.0

Will be the fully modern release that drops maintenance legacy support in favor of increased performance, ease of use, and maintainability.

* expects to drop Tracepoint collection engine
* expects to drop anything below Ruby 2.3
* Release will be aimed as significantly simplifying ease of use
   * expects to drop the concept of baseline recordings
   * improve support for eager-loading
   * add built-in support for easy loading via Railties
   * expects to add safe list support to force reload files one wants coverage on that may happen outside of the standard load order
   * built in support for activejob, sidekiq, and other common frameworks
* code route tracing (entry point to all code executed for example /some_path -> code coverage of that path)

# Released

### 2.0.2

* fix possible nil error on files that changed since initial recording @viktor-silakov
* add improve error logging in verbose mode (stacktrace) @viktor-silakov 
* improved logging level support @viktor-silakov 
* launch Coverband demo and integrate into Readme / Documentation

### 2.0.1

* add support for fine grained S3 configuration via Coverband config, thanks @a0s
  * https://github.com/danmayer/coverband/pull/98 
* Using the file argument to self.configure in lib/coverband.rb, thanks @ThomasOwens
  * https://github.com/danmayer/coverband/pull/100
* added redis improvements allowing namespace and TTL thx @oded-zahavi 
* fix warnings about duplicate method definition 
* Add support for safe_reload_files based on full file path 
* Add support for Sinatra admin control endpoints
* improved documentation

### 2.0.0

Major release with various backwards compatibility breaking changes (generally related to the configuration). The 2.0 lifecycle will act as a mostly easy upgrade that supports past users looking to move to the much faster new Coverage Adapter.

* Continues to support Ruby 2.0 and up
* supports multiple collect engines, introducing the concept of multiple collector adapters
* extends the concepts of multiple storage adapters, enabling additional authors to help support Kafka, graphite, other adapters
* old require based loading, but working towards deprecating the entire baseline concept
* Introduces massive performance enhancements by moving to Ruby `Coverage` based collection
   * Opposed to sampling this is now a reporting frequency, when using `Coverage` collector
* Reduced configuration complexity
* Refactoring the code preparing for more varied storage and reporting options
* Drop Redis as a gem runtime_dependency

### 1.5.0

This is a significant release with significant refactoring a stepping stone for a 2.0 release.

* staging a changes.md document!
* refactored out full abstraction for stores
* supports hit counts vs binary covered / not covered for lines
  * this will let you find density of code usage just not if it was used
  * this is a slight performance hit, so you can fall back to the old system if you want `redisstore.new(@redis, array: true)`
  * this is the primary new feature in 1.5.0
* Redis has configurable base name, so I can safely change storage formats between releases
* improved documentation
* supports `SimpleCov.root`
* show files that were never touched
* apply coverband filters to ignore files in report not just collection
* improved test coverage
* improved benchmarks including support for multiple stores ;)

### 1.3.1

* This was a small fix release addressing some issues
* mostly readme updates
* last release prior to having a changes document!
