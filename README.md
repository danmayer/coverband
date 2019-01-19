# Coverband

[![Build Status](https://travis-ci.org/danmayer/coverband.svg?branch=master)](https://travis-ci.org/danmayer/coverband)
[![Coverage Status](https://coveralls.io/repos/github/danmayer/coverband/badge.svg?branch=master)](https://coveralls.io/github/danmayer/coverband?branch=master)

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#coverage-report">Coverage Report</a> •
  <a href="#verify-correct-installation">Verify Correct Installation</a> •
  <a href="#advanced-config">Advanced Config</a> •
  <a href="#license">License</a> •
  <a href="/changes.md">Change Log / Roadmap</a>
</p>

A gem to measure production code usage, showing a counter for the number of times each line of code that is executed. Coverband allows easy configuration to collect and report on production code usage. It reports in the background via a thread or can be used as Rack middleware, or manually configured to meet any need.

__Note:__ Coverband is not intended for test code coverage, for that we recommended using [SimpleCov](https://github.com/colszowka/simplecov).

## Key Features

The primary goal of Coverband is giving deep insight into your production runtime usage of your application code, while having the least impact on performance possible.

* Low performance overhead
* Very simple setup and configuration
* Out of the box support for all standard code execution paths (web, cron, background jobs, rake tasks, etc)
* Easy to understand actionable insights from the report
* Development mode, offers deep insight of code usage details (number of LOC execution during single request, etc) during development.
* Mountable web interface to easily share reports

# Installation

## Redis

Coverband stores coverage data in Redis. The Redis endpoint is looked for in this order: 

1. `ENV['COVERBAND_REDIS_URL']`
2. `ENV['REDIS_URL']`
3. `localhost`

## Gem Installation

Add this line to your application's `Gemfile`, remember to `bundle install` after updating:

```bash
gem 'coverband'
```

## Rails

The Railtie integration means you shouldn't need to do anything anything else. If you have an issue with that, please [file an issue](https://github.com/danmayer/coverband/issues).


## Sinatra

For the best coverage you want this loaded as early as possible. I have been putting it directly in my `config.ru` but you could use an initializer, though you may end up missing some boot up coverage. To start collection require Coverband as early as possible.

```ruby
require 'coverband'
require File.dirname(__FILE__) + '/config/environment'

use Coverband::Middleware
run ActionController::Dispatcher.new
```

# Coverage Report

Coverband comes with a mountable rack app for viewing reports. For Rails this can be done in `config/routes.rb` with:

```ruby
Rails.application.routes.draw do
  mount Coverband::Reporters::Web.new, at: '/coverage'
end
```

But don't forget to *protect your source code with proper authentication*. Something like this when using devise:

```ruby
Rails.application.routes.draw do
  authenticate :user, lambda { |u| u.admin? } do
    mount Coverband::Reporters::Web.new, at: '/coverage'
  end
end
```

### Rake Tasks

The rake task generates a report locally and opens a browser pointing to `coverage/index.html`.

`rake coverband:coverage`

This is mostly useful in your local development environment.

# Verify Correct Installation

* boot up your application
* run app and hit a controller (via a web request, at least one request must complete)
* run `rake coverband:coverage` this will show app initialization coverage
* make another request, or enough that your reporting frequency will trigger
* run `rake coverband:coverage` and you should see coverage increasing for the endpoints you hit.

# Coverband Demo

Take Coverband for a spin on the live Heroku deployed [Coverband Demo](https://coverband-demo.herokuapp.com/). The [full source code for the demo](https://github.com/danmayer/coverband_demo) is available to help with installation, configuration, and understanding of basic usage.

### Coverband Web Endpoint

The web endpoint is a barebones endpoint that you can either expose direct (after authentication) or you can just link to the actions you wish to expose. The index is intended as a example to showcase all the features.

![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_web_update.png)
> The web index as available on the Coverband Demo site

* __force coverage collection:__ This triggers coverage collection on the current webserver process
* __reload Coverband files:__ This has Coverband reload files as configured (force reload of some files that might not capture Coverage on boot)
* __clear coverage report:__ This will clear the coverage data. This wipes out all collected data (__dangerous__)

### Example apps

- [Rails 5.2.x App](https://github.com/danmayer/coverband_demo)
- [Sinatra app](https://github.com/danmayer/churn-site)
- [Non Rack Ruby app](https://github.com/danmayer/coverband_examples)

### Example Output

Since Coverband is [Simplecov](https://github.com/colszowka/simplecov) output compatible it should work with any of the `SimpleCov::Formatter`'s available. The output below is produced using the default Simplecov HTML formatter.

Index Page
![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_index.png)

Details on a example Sinatra app
![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_details.png)

# Advanced Config


If you need to configure coverband, this can be done by creating a `config/coverband.rb` file relative to your project root.

* See [lib/coverband/configuration.rb](https://github.com/danmayer/coverband/blob/master/lib/coverband/configuration.rb) for all options
* By default Coverband will try to stored data to Redis
	* Redis endpoint is looked for in this order: `ENV['COVERBAND_REDIS_URL']`, `ENV['REDIS_URL']`, or `localhost`

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

  # config options false, true, or 'debug'. Always use false in production
  # true and debug can give helpful and interesting code usage information
  # they both increase the performance overhead of the gem a little.
  # they can also help with initially debugging the installation.
  config.verbose = false
end
```

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

### Clear Coverage

Now that Coverband uses MD5 hashes there should be no reason to manually clear coverage unless one is testing, changing versions, possibly debugging Coverband itself.

`rake coverband:clear`

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

### Forcing Coverband to Track Coverage on files loaded during boot `safe_reload_files`

Coverband will report code usage for anything `required` or `loaded` after calling `Coverband.start` which happens automatically when coverband is required. This means some of the files loaded before coverband such as the Rails application.rb will be reported as having no coverage.

The `safe_reload_files` reload option in the configuration options can help to ensure you can track any files regardless of loading before Coverband. For example if I wanted to show the coverage of `config/coverband.rb`, which has to be loaded before calling `Coverband.start`, I could do that by adding that path to the `safe_reload_files` option.

```
Coverband.configure do |config|
  # ... a bunch of other options
  # using the new safe reload to enforce files loaded
  config.safe_reload_files = ['config/coverband.rb']
end
```
By adding any files above you will get reporting on those files as part of your coverage runtime report.


### Collecting Gem / Library Usage

By default Coverband has assumed you are trying to track your application code usage and not all the supporting framework and library (Gems) code usage. There are reasons to track library usage though such as finding out which Gems aren't actually being used within production. See some of the discussion on [issue 21](https://github.com/danmayer/coverband/issues/21).

How to collect gem usage with Coverband:

* use the `safe_reload_files` feature to add the path of all gem files you wish to track
* --- or ---
* ensure you call `require 'coverband'` which triggers `Coverband.start` before loading all your gems
   * while possible this is currently hard as Rails and most environments load your whole Gemfile
   * we are looking for an improve and easier way to support this.


### Verbose Debug / Development Mode

Note: To debug issues getting Coverband working. I recommend running in development mode, by turning verbose logging on `config.verbose = true` and passing in the Rails.logger `config.logger = Rails.logger` to the Coverband config. This makes it easy to follow in development mode. Be careful to not leave these on in production as they will affect performance.

---

If you are trying to debug locally wondering what code is being run during a request. The verbose modes `config.verbose = true` and `config.verbose = 'debug'` can be useful. With true set it will output the number of lines executed per file, to the passed in log. The files are sorted from least used file to most active file. I have even run that mode in production without much of a problem. The debug verbose mode outputs both file usage and provides the number of calls per line of code. For example if you see something like below which indicates that the `application_helper` has 43150 lines executed. That might seem odd. Then looking at the breakdown of `application_helper` we can see that line `516` was executed 38,577 times. That seems bad, and is likely worth investigating perhaps memoizing or cacheing is required.

    config.verbose = 'debug'

    coverband file usage:
      [["/Users/danmayer/projects/app_name/lib/facebook.rb", 6],
      ["/Users/danmayer/projects/app_name/app/models/some_modules.rb", 9],
      ...
      ["/Users/danmayer/projects/app_name/app/models/user.rb", 2606],
      ["/Users/danmayer/projects/app_name/app/helpers/application_helper.rb",
      43150]]

    file:
      /Users/danmayer/projects/app_name/app/helpers/application_helper.rb =>
      [[448, 1], [202, 1],
      ...
     [517, 1617], [516, 38577]]


### Conflicting .Simplecov: Issue with Missing or 0% Coverage Report

If you use SimpleCov to generate code coverage for your tests. You might have setup a `.simplecov` file to help control and focus it's output. Often the settings you want for your test's code coverage report are different than what you want Coverband to be reporting on. Since Coverband uses the SimpleCov HTML formatter to prepare it's report.

So if you had something like this in a `.simplecov` file in the root of your project, as reported in [issue 83](https://github.com/danmayer/coverband/issues/83)

```
require 'simplecov'

SimpleCov.start do
  add_filter 'app/admin'
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter 'userevents'
end
```

You could see some confusing results... To avoid this issue Coverband has a Rake task that will ignore all Simplecov filters.

`rake coverband:coverage_no_filters`

This will build the report after disabling any `.simplecov` applied settings.

# Prerequisites

* Coverband 3.0.X+ requires Ruby 2.3+
* Coverband currently requires Redis for production usage

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

* run tests: 
   * `bundle exec rake` 
   * `BUNDLE_GEMFILE=Gemfile.rails4 bundle exec rake` (Same tests using rails 4 instead of 5)
* view test coverage: `open coverage/index.html`
* run the benchmarks before and after your change to see impact
   * `rake benchmarks` 

### Known Issues

* __total fail__ on front end code, because of the precompiled template step basically coverage doesn't work well for `erb`, `slim`, and the like.
  * related it will try to report something, but the line numbers reported for `ERB` files are often off and aren't considered useful. I recommend filtering out .erb using the `config.ignore` option. The default configuration excludes these files
* If you have SimpleCov filters, you need to clear them prior to generating your coverage report. As the filters will be applied to Coverband as well and can often filter out everything we are recording.
* coverage doesn't show for Rails `config/application.rb` or `config/boot.rb` as they get loaded when loading the Rake environment prior to starting the `Coverage` library.

### Debugging Redis Store

What files have been synced to Redis?

`Coverband.configuration.store.covered_files`

What is the coverage data in Redis?

`Coverband.configuration.store.coverage`

# License

This is a MIT License project...
See the file license.txt for copying permission.
