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
- Splits load time (Rails eager load) and Run time metrics
- Easy to understand actionable insights from the report
- Tracks Gem usage (still in experimental stages and not recommended for production)
- Development mode, offers deep insight of code usage details (number of LOC execution during single request, etc) during development.
- Mountable web interface to easily share reports

# Installation

## Redis

Coverband stores coverage data in Redis. The Redis endpoint is looked for in this order:

1. `ENV['COVERBAND_REDIS_URL']`
2. `ENV['REDIS_URL']`
3. `localhost`

The redis store can also be explicitly defined within the coverband.rb. See [advanced config](#advanced-config).

## Gem Installation

Add this line to your application's `Gemfile`, remember to `bundle install` after updating:

```bash
gem 'coverband'
```

If [tracking gem usage](#collecting-gem--library-usage), be sure to include coverband before other gems you would like to track.

## Upgrading to Latest

### No custom code or middleware required

With older versions of coverband, projects would report to redis using rack or sidekiq middleware. After coverband 4.0, this should no longer be required and could cause performance issues. Reporting to redis is now automatically done within a background thread with no custom code needed.

See [changelog](https://github.com/danmayer/coverband/blob/master/changes.md).

## Rails

The Railtie integration means you shouldn't need to do anything else other than ensure coverband is required after rails within your Gemfile. The only exception to this is gem tracking of `Bundle.require` which depends on requiring coverband within the application.rb. See [Collecting Gem / Library Usage](https://github.com/danmayer/coverband#collecting-gem--library-usage).

## Sinatra

For the best coverage you want this loaded as early as possible. I have been putting it directly in my `config.ru` but you could use an initializer, though you may end up missing some boot up coverage. To start collection require Coverband as early as possible.

```ruby
require 'coverband'
require File.dirname(__FILE__) + '/config/environment'

use Coverband::BackgroundMiddleware
run ActionController::Dispatcher.new
```

# Coverage Report

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

or you can enable basic auth by setting `ENV['COVERBAND_PASSWORD']` or via your configuration `config.password = 'my_pass'`

### Coverband Web Endpoint

The web endpoint is a barebones endpoint that you can either expose direct (after authentication) or you can just link to the actions you wish to expose. The index is intended as a example to showcase all the features.

![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_web_ui.png)

> The web index as available on the Coverband Demo site

- **force coverage collection:** This triggers coverage collection on the current webserver process
- **clear coverage report:** This will clear the coverage data. This wipes out all collected data (**dangerous**)
- View individual file details
- **clear individual file coverage:** This will clear the details of the file you are looking at. This is helpful if you don't want to lose all Coverage data but made a change that you expect would impact a particular file.

### Rake Tasks

The rake task generates a report locally and opens a browser pointing to `coverage/index.html`.

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
  # configure S3 integration
  config.s3_bucket = 'coverband-demo'
  config.s3_region = 'us-east-1'
  config.s3_access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.s3_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']

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
### View Tracking

Coverband allows an optional feature to track all view files that are used by an application.

To opt-in to this feature... enable the feature in your Coverband config.

`config.track_views = true`

![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_view_tracker.png)

### Writing Coverband Results to S3

If you add some additional Coverband configuration your coverage html report will be written directly to S3, update `config/coverband.rb` like below.

```
  # configure S3 integration
  config.s3_bucket = 'coverband-demo'
  config.s3_region = 'us-east-1'
  config.s3_access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.s3_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
```

Alternatively, Coverband if you don't set via the `config.s3_*` accessor methods will look for the standard S3 environment variables.

```
ENV['AWS_BUCKET']
ENV['AWS_REGION']
ENV['AWS_ACCESS_KEY_ID']
ENV['AWS_SECRET_ACCESS_KEY']
```

### Redis Hash Store

Coverband on very high volume sites with many server processes reporting can have a race condition. To resolve the race condition and reduce Ruby memory overhead we have introduced a new Redis storage option. This moves the some of the work from the Ruby processes to Redis. It is worth noting because of this, it has a larger demands on the Redis server. So adjust your Redis instance accordingly. To help reduce the extra redis load you can also change the background reporting time period. 

* set the new Redis store: `config.store = Coverband::Adapters::HashRedisStore.new(Redis.new(url: redis_url))`
* adjust from default 30s reporting `config.background_reporting_sleep_seconds = 120`
* reminder it is recommended to have a unique Redis per workload (background jobs, caching, Coverband), for this store, it may be more important to have a dedicated Redis.

### Clear Coverage

Now that Coverband uses MD5 hashes there should be no reason to manually clear coverage unless one is testing, changing versions, possibly debugging Coverband itself.

`rake coverband:clear`

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

### Collecting Gem / Library Usage

__WARNING:__ Gem Tracking is still in experimental stages and not recommended for production. We have some performance issues when view reports on large applications. Gem tracing also during background thread data collection has HIGH memory requirements, during report merging (seemingly around 128mb of extra memory, which is crazy). We recommend deploying WITHOUT `track_gems` first and only enabling it after confirming that Coverband is working and performing well.

Gem usage can be tracked by enabling the `track_gems` config.

```
Coverband.configure do |config|
  config.track_gems = true
end
```

The `track_gems` feature exposes a Gems tab in the report which prints out the percentage usage of each Gem. See demo [here](https://coverband-demo.herokuapp.com/coverage?#_Gems).

When tracking gems, it is important that `Coverband#start` is called before the gems to be tracked are required. The best way to do this is to require coverband before Bundle.require is called. Within rails, require coverband within the application.rb like so:

```ruby
require 'coverband'
Bundler.require(*Rails.groups)
```

If you are using the resque integration, resque needs to be required before coverband since the integration will not run unless resque is loaded. Within the application.rb just require resque before coverband.

```ruby
require 'resque'
require 'coverband'
Bundler.require(*Rails.groups)
```

The track_gems config only exposes the overall usage of a gem. In order to see the detail of each file, enable the `gem_details` flag.

```
Coverband.configure do |config|
  config.track_gems = true
  config.gem_details = true
end
```

This flag exposes line by line usage of gem files. Unfortunately due to the way the coverband report is currently rendered, enabling `gem_details` slows down viewing of the coverage report in the browser and is not yet recommended.

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
  - `BUNDLE_GEMFILE=Gemfile.rails4 bundle exec rake` (Same tests using rails 4 instead of 5)
- view test coverage: `open coverage/index.html`
- run the benchmarks before and after your change to see impact
  - `rake benchmarks`
  - run a single test by line number like rspec: `bundle exec m test/coverband/reporters/html_test.rb:29`

### Known Issues

- **total fail** on front end code, for line for line coverage, because of the precompiled template step basically coverage doesn't work well for `erb`, `slim`, and the like.
  - related it will try to report something, but the line numbers reported for `ERB` files are often off and aren't considered useful. I recommend filtering out .erb using the `config.ignore` option. The default configuration excludes these files
  - **NOTE:** We now have file level coverage for view files, but don't support line level detail

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
