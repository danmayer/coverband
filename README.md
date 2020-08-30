<img src="https://raw.github.com/danmayer/coverband/master/docs/assets/logo/heads.svg?sanitize=true" width='300'>

# Coverband

[![Build Status](https://travis-ci.org/danmayer/coverband.svg?branch=master)](https://travis-ci.org/danmayer/coverband)
[![Coverage Status](https://coveralls.io/repos/github/danmayer/coverband/badge.svg?branch=master)](https://coveralls.io/github/danmayer/coverband?branch=master)
[![Maintainability](https://api.codeclimate.com/v1/badges/1e6682f9540d75f26da7/maintainability)](https://codeclimate.com/github/danmayer/coverband/maintainability)
[![Discord Shield](https://img.shields.io/discord/609509533999562753)](https://discord.gg/KAH38EV)

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#coverage-report">Coverage Report</a> •
  <a href="#advanced-config">Advanced Config</a> •
  <a href="#license">License</a> •
  <a href="/changes.md">Change Log / Roadmap</a> •
  <a href="/CODE_OF_CONDUCT.md">Code of Conduct</a>
</p>

A gem to measure production code usage, showing a counter for the number of times each line of code that is executed. Coverband allows easy configuration to collect and report on production code usage. It reports in the background via a thread or can be used as Rack middleware, or manually configured to meet any need.

**Note:** Coverband is not intended for test code coverage, for that we recommended using [SimpleCov](https://github.com/colszowka/simplecov).

## Key Features

The primary goal of Coverband is giving deep insight into your production runtime usage of your application code, while having the least impact on performance possible.

- Low performance overhead
- Simple setup and configuration
- Out of the box support for all standard code execution paths (web, cron, background jobs, rake tasks, etc)
- Splits load time (Rails eager load) and runtime metrics
- Easy to understand actionable insights from the report
- Development mode, offers deep insight of code usage details (number of LOC execution during single request, etc) during development.
- Mountable web interface to easily share reports

# Installation

## Redis

Coverband stores coverage data in Redis. The Redis endpoint is looked for in this order:

1. `ENV['COVERBAND_REDIS_URL']`
2. `ENV['REDIS_URL']`
3. `localhost:6379`

The redis store can also be explicitly defined within the coverband.rb. See [advanced config](#advanced-config).

## Gem Installation

Add this line to your application's `Gemfile`, remember to `bundle install` after updating:

```bash
gem 'coverband'
```

## Upgrading to Latest

### No custom code or middleware required

With older versions of coverband, projects would report to redis using rack or sidekiq middleware. After coverband 4.0, this should no longer be required and could cause performance issues. Reporting to redis is now automatically done within a background thread with no custom code needed.

See [changelog](https://github.com/danmayer/coverband/blob/master/changes.md).

## Rails

The Railtie integration means you shouldn't need to do anything else other than ensure Coverband is required after Rails within your Gemfile.

## Sinatra

For the best coverage you want this loaded as early as possible. We recommend requiring cover band directly in the `config.ru`.  Requiring coverband within an initializer could also work, but you may end up missing some boot up coverage. To start collection require Coverband as early as possible.

```ruby
require 'coverband'
require File.dirname(__FILE__) + '/config/environment'

use Coverband::BackgroundMiddleware
run ActionController::Dispatcher.new
```

# Coverage Report

### Mounting the Rack APP

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

The coverage server can be started standalone with a rake task:

```
 bundle exec rake coverband:coverage_server
```

The web UI should then be available here: http://localhost:1022/

This is especially useful for projects that are api only and cannot support the mounted rack app. To get production coverage, point coverband at your production redis server and ensure to checkout the production version of the code locally.

```
 COVERBAND_REDIS_URL=redis://username:password:redis_production_server:2322 bundle exec rake coverband:coverage_server
```



### Coverband Web UI

![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_web_ui.png)

> The web index as available on the [Coverband Demo site](https://coverband-demo.herokuapp.com/coverage?#_Coverage)

- View overall coverage information

- Drill into individual file coverage

- View individual file details

- Clear Coverage - disabled by default as it could be considered a danager operation in production. Enable with `config.web_enable_clear` or leave off and clear from [rake task](#clear-coverage).
  - Clear coverage report
  
      This will clear the coverage data. This wipes out all collected data. 
  - Clear individual file coverage

      This will clear the details of the file you are looking at. This is helpful if you don't want to lose all Coverage data but made a change that you expect would impact a particular file.
  
- Force coverage collection

  This triggers coverage collection on the current webserver process. Useful in development but confusing in production environments where many ruby processes are usually running.



### JRuby Support

Coverband is compatible with JRuby. If you want to run on JRuby note that I haven't benchmarked and I believe the perf impact on older versions of JRuby could be significant. Improved Coverage support is in [JRuby master](https://github.com/jruby/jruby/pull/6180), and will be in the next release.

- older versions of JRuby need tracing enabled to work (and this could cause bad performance)
  - run Jruby with the `--debug` option
  - add into your `.jrubyrc` the `debug.fullTrace=true` setting
- For best performance the `oneshot_lines` is recommended, and in the latest releases should have very low overhead
- See JRuby support in a Rails app configured to run via JRuby, in [Coverband Demo](https://github.com/coverband-service/coverband_demo)
- JRuby is tested via CI against Rails 5 and 6

### Rake Tasks

`rake coverband:coverage`

This is mostly useful in your local development environment.

##### Example Output

Since Coverband is [Simplecov](https://github.com/colszowka/simplecov) output compatible it should work with any of the `SimpleCov::Formatter`'s available. The output below is produced using the default Simplecov HTML formatter.

Index Page
![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_index.png)

Details on an example Sinatra app
![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_details.png)

# Coverband Demo

Take Coverband for a spin on the live Heroku deployed [Coverband Demo](https://coverband-demo.herokuapp.com/). The [full source code for the demo](https://github.com/danmayer/coverband_demo) is available to help with installation, configuration, and understanding of basic usage.

### Example apps

- [Rails 5.2.x App](https://github.com/danmayer/coverband_demo)
- [Sinatra app](https://github.com/danmayer/churn-site)
- [Non Rack Ruby app](https://github.com/danmayer/coverband_examples)

# Advanced Config

If you need to configure coverband, this can be done by creating a `config/coverband.rb` file relative to your project root.

- See [lib/coverband/configuration.rb](https://github.com/danmayer/coverband/blob/master/lib/coverband/configuration.rb) for all options
- By default Coverband will try to stored data to Redis \* Redis endpoint is looked for in this order: `ENV['COVERBAND_REDIS_URL']`, `ENV['REDIS_URL']`, or `localhost`

Below is an example config file for a Rails 5 app:

```ruby
#config/coverband.rb
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
end
```

### Working with environment variables

Do you use figaro, mc-settings, dotenv or something else to inject environment variables into your app? If so ensure you have that done BEFORE coverband is required.

For example if you use dotenv, you need to do this, see https://github.com/bkeepers/dotenv#note-on-load-order

```
gem 'dotenv-rails', require: 'dotenv/rails-now'
gem 'coverband'
gem 'other-gem-that-requires-env-variables'
```

### Ignoring Files

Sometimes you have files that are known to be valuable perhaps in other environments or something that is just run very infrequently. Opposed to having to mentally filter them out of the report, you can just have them ignored in the Coverband reporting by using `config.ignore` as shown below. Ignore takes a string but can also match with regex rules see how below ignores all rake tasks as an example.

```
config.ignore +=  ['config/application.rb',
                   'config/boot.rb',
                   'config/puma.rb',
                   'config/schedule.rb',
                   'bin/*',
                   'config/environments/*',
                   'lib/tasks/*']
```

**Ignoring Custom Gem Locations:** Note, if you have your gems in a custom location under your app folder you likely want to add them to `config.ignore`. For example, if you have your gems not in a default ignored location of `app/vendor` but have them in `app/gems` you would need to add `gems/*` to your ignore list.

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

or if you know you are manually calling eager load anywhere in your initialization process immediately adfter call those two lines. A user reported an issue after calling `ResqueWeb::Engine.eager_load!` for example.

```ruby
Rails.application.routes.draw do
  ResqueWeb::Engine.eager_load!
  Coverband.report_coverage
  Coverband.runtime_coverage!
end
```

### Avoiding Cache Stampede

If you have many servers and they all hit Redis at the same time you can see spikes in your Redis CPU, and memory. This is do to a concept called [cache stampede](https://en.wikipedia.org/wiki/Cache_stampede). It is better to spread out the reporting across your servers. A simple way to do this is to add a random wiggle on your background reporting. This configuration option allows a wiggle. The right amount of wiggle depends on the numbers of servers you have and how willing you are to have delays in your coverage reporting. I would recommend at least 1 second per server. Note, the default wiggle is set to 30 seconds.

Add a wiggle (in seconds) to the background thread to avoid all your servers reporting at the same time:

`config.reporting_wiggle = 30`

### Redis Hash Store

Coverband on very high volume sites with many server processes reporting can have a race condition which can cause hit counts to be inaccurate. To resolve the race condition and reduce Ruby memory overhead we have introduced a new Redis storage option. This moves the some of the work from the Ruby processes to Redis. It is worth noting because of this, it has a larger demands on the Redis server. So adjust your Redis instance accordingly. To help reduce the extra redis load you can also change the background reporting frequency.

- Use a dedicated coverband redis instance: `config.store = Coverband::Adapters::HashRedisStore.new(Redis.new(url: redis_url))`
- Adjust from default 30s reporting `config.background_reporting_sleep_seconds = 120`

See more discussion [here](https://github.com/danmayer/coverband/issues/384).

### Clear Coverage

Now that Coverband uses MD5 hashes there should be no reason to manually clear coverage unless one is testing, changing versions, possibly debugging Coverband itself.

`rake coverband:clear`

This can also be done through the web if `config.web_enable_clear` is enabled.

### Coverage Data Migration

Between the release of 4.0 and 4.1 our data format changed. This resets all your coverage data. If you want to restore your previous coverage data, feel free to migrate.

`rake coverband:migrate`

- We will be working to support migrations going forward, when possible

### Adding Rake Tasks outside of Rails

Rails apps should automaticallly include the tasks via the Railtie.

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

Coverband starts on require of the the library which is usually done within the Gemfile. This can be disabled by setting the `COVERBAND_DISABLE_AUTO_START` environment variable. This environment variable can be useful to toggle coverband on and off in certain environments.

In order to start coverband manually yourself when this flag is enabled, call `Coverband.configure` followed by `Coverband.start`.

```ruby
Coverband.configure
Coverband.start
```

### Verbose Debug / Development Mode

Note: To debug issues getting Coverband working. I recommend running in development mode, by turning verbose logging on `config.verbose = true` and passing in the Rails.logger `config.logger = Rails.logger` to the Coverband config. We respect the log level, and I would recommend log level info generally, but if you are investigating a prolbem Coverband logs additional data at the `debug` level. This makes it easy to follow in development mode. Be careful to not leave these on in production as they will affect performance.

---

If you are trying to debug locally wondering what code is being run during a request. The verbose modes `config.verbose = true` && `Rails.logger.level = :debug`. With true set it will output the number of lines executed per file, to the passed in log.

### Solving: stack level too deep errors

If you start seeing SystemStackError: stack level too deep errors from background jobs after installing Coverband, this means there is another patch for ResqueWorker that conflicts with Coverband's patch in your application. To fix this, change coverband gem line in your Gemfile to the following:

```
gem 'coverband', require: ['alternative_coverband_patch', 'coverband']
```

If you currently have require: false, remove the 'coverband' string from the require array above so the gem line becomes like this:

```
gem 'coverband', require: ['alternative_coverband_patch']
```

This conflict happens when a ruby method is patched twice, once using module prepend, and once using method aliasing. See this ruby issue for details. The fix is to apply all patches the same way. Coverband by default will apply its patch using prepend, but you can change that to  method aliasing by adding require: ['alternative_coverband_patch'] to the gem line as shown above.

# Prerequisites

- Coverband 3.0.X+ requires Ruby 2.3+
- Coverband currently requires Redis for production usage

### Ruby and Rails Version Support

We will match Heroku & Ruby's support lifetime, supporting the last 3 major Ruby releases. For details see [supported runtimes](https://devcenter.heroku.com/articles/ruby-support#supported-runtimes).

For Rails, we will follow the policy of the [Rails team maintenance policy](https://guides.rubyonrails.org/maintenance_policy.html). We officially support the last two major release versions, while providing minimal support (major bugs / security fixes) for an additional version. This means at the moment we primaryly target Rails 6.x, 5.x, and will try to keep current functionality working for Rails 4.x but may release new features that do not work on that target.

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
  - `BUNDLE_GEMFILE=Gemfile.rails6 bundle exec rake` (Same tests using rails 6 instead of 5)
- view test coverage: `open coverage/index.html`
- run the benchmarks before and after your change to see impact
  - `rake benchmarks`
  - run a single test by line number like rspec: `bundle exec m test/coverband/reporters/html_test.rb:29`

### Known Issues

- **total fail** on front end code, for line for line coverage, because of the precompiled template step basically coverage doesn't work well for `erb`, `slim`, and the like.
  - related it will try to report something, but the line numbers reported for `ERB` files are often off and aren't considered useful. I recommend filtering out .erb using the `config.ignore` option. The default configuration excludes these files
  - **NOTE:** We now have file level coverage for view files, but don't support line level detail
  - The view file detection doesn't workf or mailers at the moment only for web related views / JSON templates. This is due to how Rails active mailer notifications work.

### Debugging Redis Store

What files have been synced to Redis?

`Coverband.configuration.store.covered_files`

What is the coverage data in Redis?

`Coverband.configuration.store.coverage`

## Logo

The Coverband logo was created by [Dave Woodall](http://davewoodall.com). Thanks Dave!

# License

This is a MIT License project...
See the file license.txt for copying permission.
