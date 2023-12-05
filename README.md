<img src="https://raw.github.com/danmayer/coverband/master/docs/assets/logo/heads.svg?sanitize=true" width='300'>

# Coverband

[![GithubCI](https://github.com/danmayer/coverband/workflows/CI/badge.svg)](https://github.com/danmayer/coverband/actions)
[![Coverage Status](https://coveralls.io/repos/github/danmayer/coverband/badge.svg?branch=master)](https://coveralls.io/github/danmayer/coverband?branch=master)
[![Maintainability](https://api.codeclimate.com/v1/badges/1e6682f9540d75f26da7/maintainability)](https://codeclimate.com/github/danmayer/coverband/maintainability)
[![Discord Shield](https://img.shields.io/discord/609509533999562753)](https://discord.gg/KAH38EV)

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#coverband-web-ui">Coverband Web UI</a> •
  <a href="#advanced-config">Advanced Config</a> •
  <a href="#newer-features">Newer Features</a> •
  <a href="#license">License</a> •
  <a href="/changes.md">Change Log / Roadmap</a> •
  <a href="/CODE_OF_CONDUCT.md">Code of Conduct</a>
</p>

A gem to measure production code usage, showing a counter for the number of times each line of code is executed. Coverband allows easy configuration to collect and report on production code usage. It reports in the background via a thread, can be used as Rack middleware, or can be manually configured to meet any need.

**Note:** Coverband is not intended for test code coverage; for that we recommend using [SimpleCov](https://github.com/colszowka/simplecov).

## Key Features

The primary goal of Coverband is to give you deep insight into the production runtime usage of your application code, while having the least impact on performance possible.

- Low performance overhead
- Simple setup and configuration
- Out of the box support for all standard code execution paths (web, cron, background jobs, rake tasks, etc)
- Splits code loading usage (Rails eager load) and runtime usage metrics
- Easy to understand actionable insights from the report
- Mountable web interface to easily share reports

# Installation

## Redis

Coverband stores coverage data in Redis. The Redis endpoint is looked for in this order:

1. `ENV['COVERBAND_REDIS_URL']`
2. `ENV['REDIS_URL']`
3. `localhost:6379`

The redis store can also be explicitly defined within the `config/coverband.rb`. See [advanced config](#advanced-config).

## Gem Installation

Add this line to your application's `Gemfile`, remember to `bundle install` after updating:

```bash
gem 'coverband'
```

### No custom code or middleware required

With older versions of Coverband, projects would report to redis using rack or sidekiq middleware. After Coverband 4.0, this should no longer be required and could cause performance issues. Reporting to redis is now automatically done within a background thread with no custom code needed.

See [changelog](https://github.com/danmayer/coverband/blob/master/changes.md).

## Rails

The Railtie integration means you shouldn't need to do anything else other than ensure Coverband is required after Rails within your Gemfile.

## Sinatra

For the best coverage, you want this loaded as early as possible. We recommend requiring cover band directly in the `config.ru`. Requiring Coverband within an initializer could also work, but you may end up missing some boot up coverage. To start collection require Coverband as early as possible.

```ruby
require 'coverband'
require File.dirname(__FILE__) + '/config/environment'

use Coverband::BackgroundMiddleware
run ActionController::Dispatcher.new
```

## Coverband Web UI

![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_web_ui.png)

> The web index is available on the [Coverband Demo site](https://coverband-demo.herokuapp.com/coverage?#_Coverage).

- View overall coverage information

- Drill into individual file coverage

- View individual file details

- Clear Coverage - disabled by default as it could be considered a dangerous operation in production. Enable with `config.web_enable_clear` or leave off and clear from the [rake task](#clear-coverage).

  - Clear coverage report

    This will clear the coverage data. This wipes out all collected data.

  - Clear individual file coverage

    This will clear the details of the file you are looking at. This is helpful if you don't want to lose all Coverage data but made a change that you expect would impact a particular file.

- Force coverage collection

  This triggers coverage collection on the current webserver process. Useful in development but confusing in production environments where many ruby processes are usually running.

### Mounting as a Rack App

Coverband comes with a mountable rack app for viewing reports. For Rails this can be done in `config/routes.rb` with:

```ruby
Rails.application.routes.draw do
  mount Coverband::Reporters::Web.new, at: '/coverage'
end
```

But don't forget to _protect your source code with proper authentication_. Something like this when using devise:

```ruby
Rails.application.routes.draw do
  authenticate :user, lambda { |u| u.admin? } do
    mount Coverband::Reporters::Web.new, at: '/coverage'
  end
end
```

or you can enable basic auth by setting `ENV['COVERBAND_PASSWORD']` or via your configuration `config.password = <YOUR_COMPLEX_UNGUESSABLE_PASSWORD>`

### Standalone

The coverage server can also be started standalone with a rake task:

```
bundle exec rake coverband:coverage_server
```

The web UI should then be available here: http://localhost:9022/

If you want to run on an alternative port:

```
COVERBAND_COVERAGE_PORT=8086 bundle exec rake coverband:coverage_server
```

This is especially useful for projects that are api only and cannot support the mounted rack app. To get production coverage, point Coverband at your production redis server and ensure to checkout the production version of your project code locally.

```
 COVERBAND_REDIS_URL=redis://username:password@redis_production_server:2322 bundle exec rake coverband:coverage_server
```

# Coverband Demo

Take Coverband for a spin on the live Heroku deployed [Coverband Demo](https://coverband-demo.herokuapp.com/). The [full source code for the demo](https://github.com/danmayer/coverband_demo) is available to help with installation, configuration, and understanding of basic usage.

### Example apps

- [Rails 5.2.x App](https://github.com/danmayer/coverband_demo)
- [Sinatra app](https://github.com/danmayer/churn-site)
- [Non Rack Ruby app](https://github.com/danmayer/coverband_examples)

# Advanced Config

If you need to configure Coverband, this can be done by creating a `config/coverband.rb` file relative to your project root.

- See [lib/coverband/configuration.rb](https://github.com/danmayer/coverband/blob/master/lib/coverband/configuration.rb) for all options
- By default Coverband will try to store data to Redis \* Redis endpoint is looked for in this order: `ENV['COVERBAND_REDIS_URL']`, `ENV['REDIS_URL']`, or `localhost`

Below is an example config file for a Rails 5 app:

```ruby
# config/coverband.rb NOT in the initializers
Coverband.configure do |config|
  config.store = Coverband::Adapters::RedisStore.new(Redis.new(url: ENV['MY_REDIS_URL']))
  config.logger = Rails.logger

  # config options false, true. (defaults to false)
  # true and debug can give helpful and interesting code usage information
  # and is safe to use if one is investigating issues in production, but it will slightly
  # hit perf.
  config.verbose = false

  # default false. button at the top of the web interface which clears all data
  config.web_enable_clear = true

  # default false. Experimental support for tracking view layer tracking.
  # Does not track line-level usage, only indicates if an entire file
  # is used or not.
  config.track_views = true

  # default false. Experimental support for routes usage tracking.
  config.track_routes = true
end
```

### Working with environment variables

Do you use figaro, mc-settings, dotenv or something else to inject environment variables into your app? If so ensure you have that done BEFORE Coverband is required.

For example if you use dotenv, you need to do this, see https://github.com/bkeepers/dotenv#note-on-load-order

```
gem 'dotenv-rails', require: 'dotenv/rails-now'
gem 'coverband'
gem 'other-gem-that-requires-env-variables'
```

### Ignoring Files

Sometimes you have files that are known to be valuable, perhaps in other environments or something that is just run very infrequently. Opposed to having to mentally filter them out of the report, you can just have them ignored in the Coverband reporting by using `config.ignore` as shown below. Ignore takes a string but can also match with regex rules see how below ignores all rake tasks as an example.

```
config.ignore +=  ['config/application.rb',
                   'config/boot.rb',
                   'config/puma.rb',
                   'config/schedule.rb',
                   'bin/.*',
                   'config/environments/.*',
                   'lib/tasks/.*']
```

**Ignoring Custom Gem Locations:** Note, if you have your gems in a custom location under your app folder you likely want to add them to `config.ignore`. For example, if you have your gems not in the default ignored location of `app/vendor` but in `app/gems`, you would need to add `gems/*` to your ignore list.

### View Tracking

Coverband allows an optional feature to track all view files that are used by an application.

To opt-in to this feature... enable the feature in your Coverband config.

`config.track_views = true`

![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_view_tracker.png)

### Fixing Coverage Only Shows Loading Hits

If all your coverage is being counted as loading or eager_loading coverage, and nothing is showing as runtime Coverage the initialization hook failed for some reason. The most likely reason for this issue is manually calling `eager_load!` on some Plugin/Gem. If you or a plugin is altering the Rails initialization process, you can manually flip Coverband to runtime coverage by calling these two lines, in an `after_initialize` block, in `application.rb`.

```ruby
config.after_initialize do
  unless Coverband.tasks_to_ignore?
    Coverband.report_coverage # record the last of the loading coverage
    Coverband.runtime_coverage! # set all future coverage to runtime
  end
end
```

or if you know you are manually calling eager load anywhere in your initialization process immediately after call those two lines. A user reported an issue after calling `ResqueWeb::Engine.eager_load!` for example.

```ruby
Rails.application.routes.draw do
  ResqueWeb::Engine.eager_load!
  Coverband.report_coverage
  Coverband.runtime_coverage!
end
```

### Avoiding Cache Stampede

If you have many servers and they all hit Redis at the same time you can see spikes in your Redis CPU, and memory. This is due to a concept called [cache stampede](https://en.wikipedia.org/wiki/Cache_stampede).

It is better to spread out the reporting across your servers. A simple way to do this is to add a random wiggle on your background reporting. This configuration option allows a wiggle. The right amount of wiggle depends on the number of servers you have and how willing you are to have delays in your coverage reporting. I would recommend at least 1 second per server. Note, the default wiggle is set to 30 seconds.

Add a wiggle (in seconds) to the background thread to avoid all your servers reporting at the same time:

`config.reporting_wiggle = 30`

Another way to avoid cache stampede is to omit some reporting on starting servers. Coverband stores the results of eager_loading to Redis at server startup. The eager_loading results are the same for all servers, so there is no need to save all results. By configuring the eager_loading results of some servers to be stored in Redis, we can reduce the load on Redis during deployment.

```ruby
# To omit reporting on starting servers, need to defer saving eager_loading data
config.defer_eager_loading_data = true
# Store eager_loading data on 5% of servers
config.send_deferred_eager_loading_data = rand(100) < 5
# Store eager_loading data on servers with the environment variable
config.send_deferred_eager_loading_data = ENV.fetch('ENABLE_EAGER_LOADING_COVERAGE', false)
```

### Redis Hash Store

Coverband on very high volume sites with many server processes reporting can have a race condition which can cause hit counts to be inaccurate. To resolve the race condition and reduce Ruby memory overhead we have introduced a new Redis storage option. This moves the some of the work from the Ruby processes to Redis. It is worth noting because of this, it has larger demands on the Redis server. So adjust your Redis instance accordingly. To help reduce the extra redis load you can also change the background reporting frequency.

- Use a dedicated Coverband redis instance: `config.store = Coverband::Adapters::HashRedisStore.new(Redis.new(url: redis_url))`
- Adjust from default 30s reporting `config.background_reporting_sleep_seconds = 120`

See more discussion [here](https://github.com/danmayer/coverband/issues/384).

### Clear Coverage

Now that Coverband uses MD5 hashes there should be no reason to manually clear coverage unless one is testing, changing versions, or possibly debugging Coverband itself.

`rake coverband:clear`

This can also be done through the web if `config.web_enable_clear` is enabled.

### Coverage Data Migration

Between the release of 4.0 and 4.1 our data format changed. This resets all your coverage data. If you want to restore your previous coverage data, feel free to migrate.

`rake coverband:migrate`

- We will be working to support migrations going forward, when possible

### Adding Rake Tasks outside of Rails

Rails apps should automatically include the tasks via the Railtie.

For non Rails apps, either add the below to your `Rakefile` or to a file included in your `Rakefile` such as `lib/tasks/coverband.rake` if you want to break it up that way.

```ruby
require 'coverband'
Coverband.configure
require 'coverband/utils/tasks'
```

Verify it works

```bash
rake -T coverband
rake coverband:clear         # reset coverband coverage data
rake coverband:coverage      # report runtime coverband code coverage
```

### Manually Starting Coverband

Coverband starts on require of the the library which is usually done within the Gemfile. This can be disabled by setting the `COVERBAND_DISABLE_AUTO_START` environment variable. This environment variable can be useful to toggle Coverband on and off in certain environments.

**NOTE:** That any value set for `COVERBAND_DISABLE_AUTO_START` is considered true, it does not match the string content but only checks the presence of the ENV variable.

In order to start Coverband manually when this flag is enabled, call `Coverband.configure` followed by `Coverband.start`.

```ruby
Coverband.configure
Coverband.start
```

### Verbose Debug / Development Mode

Note: To debug issues getting Coverband working. I recommend running in development mode, by turning verbose logging on `config.verbose = true` and passing in the Rails.logger `config.logger = Rails.logger` to the Coverband config. We respect the log level, and I would recommend log level info generally, but if you are investigating a problem Coverband logs additional data at the `debug` level. This makes it easy to follow in development mode. Be careful not to leave these on in production as they will affect performance.

---

If you are trying to debug locally wondering what code is being run during a request. The verbose modes `config.verbose = true` && `Rails.logger.level = :debug`. With true set it will output the number of lines executed per file, to the passed in log.

### Solving: stack level too deep errors

If you start seeing SystemStackError: stack level too deep errors from background jobs after installing Coverband, this means there is another patch for ResqueWorker that conflicts with Coverband's patch in your application. To fix this, change Coverband gem line in your Gemfile to the following:

```
gem 'coverband', require: ['alternative_coverband_patch', 'coverband']
```

If you currently have require: false, remove the 'coverband' string from the require array above so the gem line becomes like this:

```
gem 'coverband', require: ['alternative_coverband_patch']
```

This conflict happens when a ruby method is patched twice, once using module prepend, and once using method aliasing. See this ruby issue for details. The fix is to apply all patches the same way. By default, Coverband will apply its patch using prepend, but you can change that to method aliasing by adding require: ['alternative_coverband_patch'] to the gem line as shown above.

### Redis Sizing Info

A few folks have asked about what size of Redis is needed to run Coverband. I have some of our largest services with hundreds of servers on cache.m3.medium with plenty of room to spare. I run most apps on the smallest AWS Redis instances available and bump up only if needed or if I am forced to be on a shared Redis instance, which I try to avoid. On Heroku, I have used it with most of the 3rd party and also been fine on the smallest Redis instances, if you have hundreds of dynos you would likely need to scale up. Also note there is a tradeoff one can make, `Coverband::Adapters::HashRedisStore` will use LUA on Redis and increase the Redis load, while being nicer to your app servers and avoid potential lost data during race conditions. While the `Coverband::Adapters::RedisStore` uses in app memory and merging and has lower load on Redis.

# Newer Features

### Dead Method Scanning (ruby 2.6+)

Rake task that outputs dead methods based on current coverage data:

```
bundle exec rake coverband:dead_methods
```

Outputs:

```
---------------------------------------------------------------------------------------------------
| file                                  | class           | method                  | line_number |
| ./config/routes.rb                    | AdminConstraint | matches?                | 20          |
| ./app/controllers/home_controller.rb  | HomeController  | trigger_jobs            | 8           |
| ./app/controllers/home_controller.rb  | HomeController  | data_tracer             | 14          |
| ./app/controllers/posts_controller.rb | PostsController | edit                    | 22          |
| ./app/controllers/posts_controller.rb | PostsController | destroy_bad_dangerously | 73          |
---------------------------------------------------------------------------------------------------
```


# Prerequisites

- Coverband 3.0.X+ requires Ruby 2.3+
- Coverband currently requires Redis for production usage

### Ruby and Rails Version Support

We will match Heroku & Ruby's support lifetime, supporting the last 3 major Ruby releases. For details see [supported runtimes](https://devcenter.heroku.com/articles/ruby-support#supported-runtimes).

For Rails, we will follow the policy of the [Rails team maintenance policy](https://guides.rubyonrails.org/maintenance_policy.html). We officially support the last two major release versions, while providing minimal support (major bugs / security fixes) for an additional version. This means at the moment we primarily target Rails 6.x, 5.x, and will try to keep current functionality working for Rails 4.x but may release new features that do not work on that target.

### JRuby Support

Coverband is compatible with JRuby. If you want to run on JRuby note that I haven't benchmarked and I believe the perf impact on older versions of JRuby could be significant. Improved Coverage support is in [JRuby master](https://github.com/jruby/jruby/pull/6180), and will be in the next release.

- older versions of JRuby need tracing enabled to work (and this could cause bad performance)
  - run Jruby with the `--debug` option
  - add into your `.jrubyrc` the `debug.fullTrace=true` setting
- For best performance the `oneshot_lines` is recommended, and in the latest releases should have very low overhead
- See JRuby support in a Rails app configured to run via JRuby, in [Coverband Demo](https://github.com/coverband-service/coverband_demo)
- JRuby is tested via CI against Rails 5 and 6

# Contributing To Coverband

If you are working on adding features, PRs, or bugfixes to Coverband this section should help get you going.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Make sure all tests are passing (run `bundle install`, make sure Redis is running, and then execute `rake test`)
6. Create new Pull Request

### Tests & Benchmarks

If you submit a change please make sure the tests and benchmarks are passing.

- run tests:
  - `bundle exec rake`
  - `BUNDLE_GEMFILE=Gemfile.rails7 bundle exec rake` (Same tests using rails 7 instead of 6)
- view test coverage: `open coverage/index.html`
- run the benchmarks before and after your change to see impact
  - `rake benchmarks`
  - run a single test by line number like rspec: `bundle exec m test/coverband/reporters/html_test.rb:29`
  - run a single test file: `bundle exec ruby test/coverband/collectors/translation_tracker_test.rb`

### Known Issues

- **total fail** on front end code, for line for line coverage, because of the precompiled template step basically coverage doesn't work well for `erb`, `slim`, and the like.
  - related it will try to report something, but the line numbers reported for `ERB` files are often off and aren't considered useful. I recommend filtering out .erb using the `config.ignore` option. The default configuration excludes these files
  - **NOTE:** We now have file level coverage for view files, but don't support line level detail
- **Coverage does NOT work when used alongside Scout APM Auto Instrumentation**
  - In an environment that uses Scout's `AUTO_INSTRUMENT=true` (usually production or staging) it stops reporting any coverage, it will show one or two files that have been loaded at the start but everything else will show up as having 0% coverage
  - Bug tracked here: https://github.com/scoutapp/scout_apm_ruby/issues/343
- **Coverband, [Elastic APM](https://github.com/elastic/apm-agent-ruby) and resque**
  - In an environment that uses the Elastic APM ruby agent, resque jobs will fail with `Transactions may not be nested. Already inside #<ElasticAPM::Transaction>` if the `elastic-apm` gem is loaded _before_ the `coverband` gem
  - Put `coverage` ahead of `elastic-apm` in your Gemfile

### Debugging Redis Store

What files have been synced to Redis?

`Coverband.configuration.store.covered_files`

What is the coverage data in Redis?

`Coverband.configuration.store.coverage`

### Diagram

A diagram of the code.

![Visualization of this repo](https://raw.githubusercontent.com/danmayer/coverband/diagram/diagram.svg)

## Logo

The Coverband logo was created by [Dave Woodall](http://davewoodall.com). Thanks Dave!

# License

This is a MIT License project...
See the file license.txt for copying permission.
