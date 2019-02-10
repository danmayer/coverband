# Future Roadmap

### Research Alternative Redis formats

- Look at alternative storage formats for Redis
  - [redis bitmaps](http://blog.getspool.com/2011/11/29/fast-easy-realtime-metrics-using-redis-bitmaps/)
  - [redis bitfield](https://stackoverflow.com/questions/47100606/optimal-way-to-store-array-of-integers-in-redis-database)
- Add support for [zadd](http://redis.io/topics/data-types-intro) so one could determine single call versus multiple calls on a line, letting us determine the most executed code in production.

### Coverband 4.X

Will be the fully modern release that drops maintenance legacy support in favor of increased performance, ease of use, and maintainability.

- Release will be aimed as significantly simplifying ease of use
  - near zero config setup for Rails apps
  - add built-in support for easy loading via Railties
  - built in support for activejob, sidekiq, and other common frameworks
  - reduced configuration options
- options on reporting
  - background reporting
  - or middleware reporting
- Support for file versions
  - md5 or release tags
  - add coverage timerange support
- Drop Simplecov dependency
- improved web reporting
  - lists current config options
  - eventually allow updating remote config
  - full theming
  - list redis data dump for debugging
- additional adapters: Memcache, S3, and ActiveRecord
- add articles / podcasts like prontos readme https://github.com/prontolabs/pronto
- Add detailed Gem usage report, if we collect and send gem usage we can give percentage of gem code used, which should help application developers know when to remove gem dependencies (0%) or perhaps inline single methods for little usage (using <= 5%) for example.
- add meta data information first seen last recorded to the coverage report views (probably need to drop simplecov for that).
  - more details in this issue: https://github.com/danmayer/coverband/issues/118
- Make good video on setup, install, usage
- See if we can add support for views / templates
  - using this technique https://github.com/ioquatix/covered
- Better default grouping (could use groups features for gems for rails controllers, models, lib, etc)  	

### Coverband_jam_session

This is a possible gem to host experimental or more complex features, which would require tuning, configuration, and performance trade offs. If something is really valuable it could be promoted into the main line.

Feature Ideas:

- statsd adapters (it would allow passing in date ranges on usage)
- move to SimpleCov console out, or make similar console tabular output
- Possibly add ability to record code run for a given route
- integrate recording with deploy tag or deploy timestamp
  - diff code usage across deployed versions
  - what methods increased usage or decreased
- Improve client code api, around manual usage of sampling (like event usage)
- ability to change the Coverband config at runtime by changing the config pushed to the Redis hash. In memory cache around the changes to only make that call periodically.
- Opposed to just showing code usage on a route allow 'tagging' events which would record line coverage for that tag (this would allow tagging all code that modified an ActiveRecord model for example
- additional adapters (tracepoint, ruby-profiler, etc)
- code route tracing (entry point to all code executed for example /some_path -> code coverage of that path)
- tagging of reported Coverage
- allow only to collect coverage based on route (limiting or scoped coverage)
- coverage over some other variable like a set of alpha users
- document how to use this on staging / selenium test suite runs
  - possible add API to pull report at end of run

# Alpha

### Coverband 4.2.0.alpha

???

### Coverband 4.1.0.beta

- default disabled web clear, add config option to allow it
- out of the box support for resque
- readme improvements
- fix on regression of merging directory changing deployments
- pilot release of Gems tracking (disabled by default)
	- todos
	  - support multiple gem paths (various version managers setup multiple gem paths)
	  - speed up page load by allowing multiple pages
- added web settings and debug views

# Released

### Coverband 4.0.1

- drops Simplecov runtime dependency
  - still used to measure our own code coverage ;)
- thanks SimpleCov for all the years of solid HTML reporting, and support!
- reduced the S3 dependencies to minimal set (not loading all of aws-sdk, only aws-sdk-s3), ensured they are optional
- Improved Coverband web admin
- Coverage reports include timestamps of Coverage collection
- Added Coveralls to the dev process thanks @dondonz
- now tested under Ruby 2.6.0 thanks @Kbaum
- improved full stack testing for Rails 5 & 4
- warning before clear coverage on coverband web

### Coverband 4.0.0

- Add support for Railties integration
- Reduce configuration options
- Default to background reporting vs middleware reporting
- Resolves issue requiring submitting initial coverage data pre-fork
- Simplified setup with just works sensible defaults for configuration out of the box
- Fixes on the pilot release of background reporting in 3.0.1
- Rake tasks automatically configured
- Updated and simplified documentation
- Thanks to Kbaum for all the extensive feedback on the PR

### Coverband 3.X

Will be a stable and fast release that drops maintenance legacy support in favor of increased performance and maintainability.

- expects to drop Tracepoint collection engine
- drop anything below Ruby 2.3
- release begins to simplify ease of use
  - drop collectors adapter
  - reduced configuration options
- add memory benchmarks showing memory overhead of coverband
- use full stack tests to prove no memory leaks when used in Rails

### Coverband 3.0.1

- update documentation around verification steps (https://github.com/danmayer/coverband/issues/135), thanks @kbaum
- resolve coverage drift issue, https://github.com/danmayer/coverband/issues/118, thanks for MD5 hash ideas @dnasseri and @kbaum
- first version of background thread coverage reporting https://github.com/danmayer/coverband/pull/138, thanks @kbaum
- auto-detection of Rack & Rails thanks @kbaum
- improved tests allowing exceptions to raise in tests @kbaum
- add support for both aws-sdk 1.x and 2.x thanks @jared
- adds memory test ensuring no memory leaks
- full stack Rails tests for Rails 4 and 5 thanks @kbaum

### Coverband 3.0.0

- drops Tracepoint
- drops Ruby <= 2.3.0
- drops JSON Gem dependency
- drops various other features not needed without Tracepoint
  - memory cache, sampling, restricted to app folders, etc
- standardizes on Coverage array format vs sparse hash
- rewrites store methods, for 60X perf
  - implemented for Redis and File store
- improved mountable web interface

# 2.0.3

- don''t include docs in the gemfile thanks @bquorning
- pipeline_redis to reduce network overhead thanks @Kallin
- various additional benchmarks @danmayer
- Filter out files with no coverage thanks @kbaum

### 2.0.2

- fix possible nil error on files that changed since initial recording @viktor-silakov
- add improve error logging in verbose mode (stacktrace) @viktor-silakov
- improved logging level support @viktor-silakov
- launch Coverband demo and integrate into Readme / Documentation
- fix on baseline to show an issue by @viktor-silakov
- remove all coverband:baseline related features and documentation
- dropped Sinatra requirement for web mountable page
- fix on filestore by @danrabinowitz
- fixes to the MemoryCacheStore by @kbaum

### 2.0.1

- add support for fine grained S3 configuration via Coverband config, thanks @a0s
  - https://github.com/danmayer/coverband/pull/98
- Using the file argument to self.configure in lib/coverband.rb, thanks @ThomasOwens
  - https://github.com/danmayer/coverband/pull/100
- added redis improvements allowing namespace and TTL thx @oded-zahavi
- fix warnings about duplicate method definition
- Add support for safe_reload_files based on full file path
- Add support for Sinatra admin control endpoints
- improved documentation

### 2.0.0

Major release with various backwards compatibility breaking changes (generally related to the configuration). The 2.0 lifecycle will act as a mostly easy upgrade that supports past users looking to move to the much faster new Coverage Adapter.

- Continues to support Ruby 2.0 and up
- supports multiple collect engines, introducing the concept of multiple collector adapters
- extends the concepts of multiple storage adapters, enabling additional authors to help support Kafka, graphite, other adapters
- old require based loading, but working towards deprecating the entire baseline concept
- Introduces massive performance enhancements by moving to Ruby `Coverage` based collection
  - Opposed to sampling this is now a reporting frequency, when using `Coverage` collector
- Reduced configuration complexity
- Refactoring the code preparing for more varied storage and reporting options
- Drop Redis as a gem runtime_dependency

### 1.5.0

This is a significant release with significant refactoring a stepping stone for a 2.0 release.

- staging a changes.md document!
- refactored out full abstraction for stores
- supports hit counts vs binary covered / not covered for lines
  - this will let you find density of code usage just not if it was used
  - this is a slight performance hit, so you can fall back to the old system if you want `redisstore.new(@redis, array: true)`
  - this is the primary new feature in 1.5.0
- Redis has configurable base name, so I can safely change storage formats between releases
- improved documentation
- supports `SimpleCov.root`
- show files that were never touched
- apply coverband filters to ignore files in report not just collection
- improved test coverage
- improved benchmarks including support for multiple stores ;)

### 1.3.1

- This was a small fix release addressing some issues
- mostly readme updates
- last release prior to having a changes document!
