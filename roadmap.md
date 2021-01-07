# Future Roadmap

### Research Alternative Redis formats

- Look at alternative storage formats for Redis
  - [redis bitmaps](http://blog.getspool.com/2011/11/29/fast-easy-realtime-metrics-using-redis-bitmaps/)
  - [redis bitfield](https://stackoverflow.com/questions/47100606/optimal-way-to-store-array-of-integers-in-redis-database)
- Add support for [zadd](http://redis.io/topics/data-types-intro) so one could determine single call versus multiple calls on a line, letting us determine the most executed code in production.

### Coverband Future...

Will be the fully modern release that drops maintenance legacy support in favor of increased performance, ease of use, and maintainability.

- Release will be aimed as significantly simplifying ease of use
  - near zero config setup for Rails apps
  - add built-in support for easy loading via Railties
  - built in support for activejob, sidekiq, and other common frameworks
  - reduced configuration options
- support oneshot
- drop middleware figure out a way to kick off background without middelware
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
- Improved logging for easier debugging and development
  - drop the verbose mode and better support standard logger levels
- Possibly setup a build assets system
  - my JS rules expanded the compressed JS at the top of application.js, basically we want to stitch together JS
  - I guess we could also load multiple JS files as most of the JS is just default compressed JS and a tiny amount of actual app JS.
- lazy load for Coverband results
- view layer file coverage
- move all code to work with relative paths leaving only stdlib Coverage working on full paths
- add gem_safe_lists to track only some gems
- add gem_details_safe list to report on details on some gems
- - display gems that are in loaded with 0 coverage, thanks @kbaum

# Alpha / Beta / Release Candidates

### Coverband 5.?.?