# Future Roadmap

### Research Alternative Redis formats

- Look at alternative storage formats for Redis
  - [redis bitmaps](http://blog.getspool.com/2011/11/29/fast-easy-realtime-metrics-using-redis-bitmaps/)
  - [redis bitfield](https://stackoverflow.com/questions/47100606/optimal-way-to-store-array-of-integers-in-redis-database)
- Add support for [zadd](http://redis.io/topics/data-types-intro) so one could determine single call versus multiple calls on a line, letting us determine the most executed code in production.
- Changes and updates to Ruby Coverage Library that helps support templates
  - https://github.com/ioquatix/covered
  - https://github.com/simplecov-ruby/simplecov/pull/1037
- Consider A Coverband Pro / Option to run coverband service locally
- review how humperdink / e70 track translations, particularly how humperdink uses dirty sets with redis, for perf improvements for trackers
  - https://github.com/livingsocial/humperdink
  - https://github.com/sergioisidoro/e7o/blob/master/lib/e7o.rb
- Possible Cross Application Support to track library usage?
- Reducing differences between coverband local and coverband service

### Coverband Next...

Will be the fully modern release that drops maintenance legacy support in favor of increased performance, ease of use, and maintainability.

- look at adding a DB tracker
- defaults to oneshot for coverage
- possibly splits coverage and all other covered modules
- drop middleware figure out a way to kick off background without middelware, possibly use similar process forking detection to humperdink
  - https://github.com/livingsocial/humperdink/blob/master/lib/humperdink/fork_savvy_redis.rb
- options on reporting
  - background reporting
  - or middleware reporting
- Support for file versions
  - md5 or release tags
  - add coverage timerange support
- improved web reporting
  - lists current config options
  - eventually allow updating remote config
  - full theming
  - list redis data dump for debugging (refactor built in debug support)
- additional adapters: Memcache, S3, and ActiveRecord
- add articles / podcasts like prontos readme https://github.com/prontolabs/pronto
- add meta data information first seen last recorded to the coverage report views (per file / per method?).
  - more details in this issue: https://github.com/danmayer/coverband/issues/118
- See if we can add support for views / templates
  - using this technique https://github.com/ioquatix/covered
- Better default grouping (could use groups features for gems for rails controllers, models, lib, etc)
- Improved logging for easier debugging and development
  - drop the verbose mode and better support standard logger levels
  - redo the logger entirely
- redo config system and allow live config updates via webui
- move all code to work with relative paths leaving only stdlib Coverage working on full paths

# Out of Scope

It is important for a project to not only know what problems it is trying to solve, but what things are out of scope. We will start to try to document that here:

* We have in the past tried to add coverage tracking for all gems, this added a lot of complexity and computation overhead and slowed things down to much. It also was of less value than we had hoped. There are alternative ways to instrument a shared library to track across multiple applications, and single application gem utilization is easier to handle in a one of basis. It is unlikely we will support that again.
