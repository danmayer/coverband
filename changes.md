### Coverband 6.1.7

* add back a running demo site
  * source: https://github.com/danmayer/coverband_rails_example
  * demo site: https://coverband-rails-example.onrender.com/demo
* Feature: Added MCP (Model Context Protocol) server support for AI assistants
  * Allows AI agents (like Claude) to securely query coverage data, find dead code, and analyze usage
  * Includes HTTP and Stdio transports
  * See `docs/mcp_security.md` and README for setup instructions
* Feature: Added `Coverband::MCP::HttpHandler` for mounting MCP server in Rack apps
* Improvement: Added `routes_tracker` alias for `route_tracker` in configuration
* Improvement: Better error handling when Redis is not available (defaults to NullStore with a warning)
* Improvement: Updates to `lib/coverband/utils/lines_classifier.rb` to better handle `:nocov:` markers
* Docs: Added `agents.md` for AI contributor guidelines
* Docs: Added `docs/mcp_security.md`
* Fix: Logging to `$stdout` instead of `STDOUT` to avoid warnings
* Fix: Added GitHub Issue templates and Dependabot config

### Coverband 6.1.6

* Check for Rails::Engine - Stephen Wetzel
* Support views located in components directory, as well as sub-directories like packs/app/views - Derek Kniffin

### Coverband 6.1.5

* add testing for ruby-head
* drop support for older Ruby and Rails version as matching our policy
* remove ostruct as it is no longer in ruby-head
* fix issue requiring base64 to be added to folks gem files
* added support for track_key method allowing for code to specifically mark things tracked
* improvements to CI thanks ydah
* Update README to include functionality details for "Coverage first seen" and "Last activity recorded" thanks juanarevalo
* fixes for Rack 3 - thanks Aaron Pfeifer
* Do not mark single-line and empty methods as dead - fatkodima
* fix on clear_trackers rake task
* Consider eager loaded code too when detecting dead methods - fatkodima

### Coverband 6.1.4

* fix on ignoring to many view files thx @fatkodima
* improve docs on clear

### Coverband 6.1.3

* memory optimizations thx @fatkodima
* drop support for Ruby less than 2.7 thx @fatkodima
* improved 0 missed styles thx @fatkodima
* improved sidekiq swarm support thx @fatkodima
* default include memcached adapter thx @colemanja91
* improved long filename web admin views thx @fatkodima
* reduce logging noise thx @jamiecobbett
* improved readme thx @hotoolong
* fix for ignoring views @thijsnado 
* improved documentation @jjb
* add back static output summary @bessey

other cleanup, small fixes, and updated mostly basic maintenance, by me.

### Coverband 6.1.2

* Fix for paging that would pull empty pages after getting all the data.

### Coverband 6.1.1

* Performance fix making paged report loading 10X faster

### Coverband 6.1.0

This release has a number of smaller fixes and improvements. It includes a sizable refactoring around the UI which should simplify improvements going forward. This release is mostly targeting large projects with 6K+ ruby files, use the new `config.paged_reporting = true` option with the HashRedisStore to enable paged reporting for large projects. The HashRedisStore now also includes the last time a line in a file was executed.

* Thanks to @FeLvi-zzz for the last time accessed support for the Hash Redis Store
* Thanks to @alpaca-tc for the improvements on the route tracker
* Thanks to @ydah for typo fixes, doc updates, adding ruby 3.3 to build matrix, improvements on CI, standardrb fixes
* Thanks to @trivett, @khaled-badenjki, @IsabelleLePivain  for improved docs
* Thanks to @prastamaha for the memcached adapter
* Thanks to @ursm for a yaml fix
* Thanks to @Drowze for a layered cache approach for perf improvements
* Thanks to @vs37559 for a sinatra pandrino fix
* This release addresses large projects and adds in paged reporting
  * to ensure even on projects with 10K+ files it can load on heroku under the 30s timeout
  * only supports HashRedis store
  * faster UI for web UI in general which should be noticeable on non paged reports
  * reduce redis calls

### Coverband 6.0.2

* thanks makicamel for improved deferred eager loading
* thanks Drowze for two performance improvements to reporting coverage


### Coverband 6.0.1

* [fix on reload routes](https://github.com/danmayer/coverband/commit/f7a81c9499c01a7c027e5f8bc127815bf29a5cb7)


### Coverband 6.0.0

* The 6.0.0 release is all that was the 6 different RC releases of 5.2.6
* Added Rails test matrix to github actions to test on all the supported versions
  - Rails: 6.0.x, 6.1.x, 7.0.x, 7.1.x

### Coverband 5.2.6

- add support for translation keys
- refactor non Coverage.so based trackers
- adds CSP report support (thanks @jwg2s)
- add JSON reporter (thanks @mark-davenport-fountain)
- README improvements (thanks @jfvanderwalt)
- Fix on test mode configuration (thanks @rileyanderson)
- Text Improvements (thanks @etagwerker)
- readme update on configuration options (thanks @D-system)
- fix for rack mount of class vs instance (thanks @vs37559)

### Coverband 5.2.5

- (colemanja91/danmayer) experimental support for route tracking, opt-in
- remove deprecations for old coverband, rails, and ruby versions out of support
   - Note: official support is now:
      - Ruby: 2.7.6, 3.0.4, 3.1.2 (min versions)
      - Rails: 6.0.x, 6.1.x, 7.0.x, 7.1.x

### Coverband 5.2.4

- add install task with example configuration file

### Coverband 5.2.3

- fix for thread error bubbling up
- additional documentation around Redis

### Coverband 5.2.2

- fix for deprecated redis pipeline usage by @casperisfine

### Coverband 5.2.1

- fix for `can't add a new key into hash during iteration` https://github.com/danmayer/coverband/issues/436

### Coverband 5.2.0

- (Fumiaki MATSUSHIMA) Fix CI setting for Ruby 3.0
- (Fumiaki MATSUSHIMA) Avoid calling coverage with the same type twice on get_coverage_report
- (kei-s) Fix filling zero for not loaded files
- (wonda-tea-coffee) cleanup readme / fix typos
- support deferred eager loading data
- (Donatas Stundys) Fix disabling views tracking
- (Simon) Improve View tracker to track render collection too

### Coverband 5.1.1

- Fix early report error
- Improved view tracker perf Hosam Aly

### Coverband 5.1.0

- add support for dead method detection rake task
- add support for tracking email view templates/partials

### Coverband 5.0.3

- fix for non standard root paths for view_tracker thx @markshawtoronto
- support basic auth for Rack prior to 2.0 thx @kadru

### Coverband 5.0.2

- change default port of local server
- update on readme about issue with scout app, thanks @mrbongiolo
- fix on configuration page not loading when redis can't load

### Coverband 5.0.1

- fix for race condition on view tracker redis configuration setting ensuring it is set after it is configured... bug only impacted apps that have multiple redis connections for the same system and have Coverband not on the default REDIS_URL

### Coverband 5.0.0

- Full JRuby support
- Reduced footprint
  - drops S3 support
  - drops static report support
  - drops gem support
  - only loaded web reporter files when required
- configuration improvements - improved load order allowing more time for ENV vars (better dotenv, figaro, rails secrets support) - all config options can be set via coverband config, not requiring ENV var support - deprecation notices on soon to be removed config options - config exceptions on invalid configuration combinations - additional testing around configurations - improved defaults and reduced configuration options
- improved resque patching pattern
- improved default ignores
- additional adapters
  - supports web-service adapter for http coverage collection
  - support log/file adapter
  - extendable pattern to support any additional backends
- reduce logs / errors / alerts on bad startup configurations
- fix: #301 runtime vs eagerload should always remain correct

### Coverband 4.2.7

- Ignore patterns too aggressive #382, thanks @thijsnado
- Stack level too deep error when running certain activejob jobs #367, thanks @kejordan and @hanslauwers

### Coverband 4.2.6

- Address Redis exists deprecation warning by baffers

### Coverband 4.2.5

- alpha support of jRuby
- fix for rails 4.0 by rswaminathan
- do not error on branch coverage / simplecov compatibility by desertcart

### Coverband 4.2.4

- fixes related to startup without Redis, skipping Coverband on common rake tasks (assets:precompile), etc
- avoid calls to redis if coverage not updated
- split out lua work and added testing around lua scripts use for the hash redis store
- improvements to hash redis store resulting in 25% faster perf
- avoid duplicate hash calculations
- debug data now includes md5_hashes
- added support to download coverage and view data in JSON format
- documentation about working with environment variables
- add cache wiggle to avoid Redis CPU spikes (cache stampede on Redis server)
- make the nocov consistent on the data download and html view
- small performance improvements

### Coverband 4.2.3

- readme fixes
- improved defaults for the next redis hash adapter
- add tooltips
- improved messaging around non-loaded files
- fix on last updated nil issue
- view tracker improvements
  - clear all
  - reset individual file
  - timestamps on last seen activity

### Coverband 4.2.2

- new experimental hash redis store for high volume collection
  (hundreds of clients), thanks @kbaum
- view_tracker supports tracking view layer files like `.html.erb`
- documentation improvements, thanks @brossetti1, @jjb, @kbaum
- we now have discordapp for discussions, thanks @kbaum,
  https://discordapp.com/channels/609509533999562753/609509533999562756
- perf fix on Rails initialization, thanks @skangg
- simplified logging

### Coverband 4.2.1

- larger changes
  - reduce memory usage
  - fix issue where reports didn't include files with 0 activity
  - updated runtime relevant lines and runtime percentages
  - add Oneshot coverage support for Ruby 2.6.0 thanks @zwalker
  - I would consider this our test oneshot release, please report any issues
  - improved control over memory vs functionality
    - oneshot support is the best memory and speed if you are on Ruby 2.6.\*
    - simulated_oneshot works for Ruby prior to 2.6.\*, keeps lower runtime memory, at a trade of only being able to detect eager_load or runtime hits not both
    - full hit tracking (The previous and current default), this uses more memory than other options, but provides full robust data

* small changes fixes
  - further improvements on eager_loading detection, thanks @kbaum
  - fix on ignore configuration options
  - fix broken static server
  - fix issue where clear and coverage trigger coverage reports
  - improved logging
  - fix on gem runtime code coverage support, thanks @kbaum
  - fix sorting of runtime coverage
  - add runtime coverage to gem summary pages
  - documented redis TTL, thanks @jjb
  - resolve regression on coverband rake tasks recording coverage
  - improved runtime / eager loading tracking
  - fix on small memory leaks
  - added warnings that gem tracking isn't production ready
  - built in support for basic auth on the web rack app, thanks @jjb
  - don't clobber rake environment method definition, thanks @shioyama
  - readme improvements, thanks @yuriyalekseyev
  - fix duplicate requires thanks @yuriyalekseyev
  - various cleanups and improvements, thanks @kbaum
  - additional benchmarks to ensure proper memory handling, thanks @kbaum
  - default redis TTL, thanks @jjb

### Coverband 4.2.0

**NOTE:** This release introduces load time and runtime Coverage. To get the full benefit of this feature you need to reset you coverage data (`rake coverband:clear` or clear via the web UI). Until you clear the combined result is still correct, but your runtime data will be mixed with previous data. This is due to an additive change in how we store coverage. We didn't reset by default as the coverage history for some folks may be more important than runtime breakdown.

- loadtime vs runtime coverage
  - This fixes the coverage last seen date to exclude just load time data
  - now you can see boot time coverage vs code hit during production execution
  - list view shows runtime percentage and runtime hits
  - file view shows line hits load, runtime, and combined
- perf speedup on gem details views
- ajax load code views for more responsive pages on large projects
- fix for issues with COVERBAND_DISABLE_AUTO_START
- silence warnings
- move from thread based reporter instance to process based instance
- thanks Karl Baum for much of the above mentioned work
- clear coverage on individual files
- we have a logo, thanks Dave Woodall, http://davewoodall.com

### Coverband 4.1.1

- fix bug on info page when using namespaces
- fix bug related to forking Ruby processes (Resque for example)
  - bug caused negative line hits
  - bug seemed to cause memory leaks (not entirely sure how)
- various test improvements
- fix bad requests on coverband web admin to `/coverage/favicon.png`
- improved documentation

### Coverband 4.1.0

- default disabled web clear, add config option to allow it
- out of the box support for resque
- readme improvements
- fix on regression of merging directory changing deployments
  - fixes for duplicate root paths
- pilot release of Gems tracking (disabled by default) - todos - support multiple gem paths (various version managers setup multiple gem paths) - speed up page load by allowing multiple pages
- added web settings and debug views
  - added support for seeing coverage data size consumed in redis
- support coverage data migrations from 4.0.x to 4.1.0
- fixes for heroku /tmp asset building

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

### 2.0.3

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
