# Coverband

Build Status: [![Build Status](https://travis-ci.org/danmayer/coverband.svg?branch=master)](https://travis-ci.org/danmayer/coverband)

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#coverband-demo">Coverband Demo</a> •
  <a href="#how-to-use">How To Use</a> •
  <a href="#installation">Installation</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#usage">Usage</a> •
  <a href="#license">License</a>
</p>

A gem to measure production code usage, showing each line of code that is executed. Coverband allows easy configuration to collect and report on production code usage. It can be used as Rack middleware, wrapping a block with sampling, or manually configured to meet any need (like usage during background jobs).

Note: Coverband is not intended for test code coverage, for that just check out [SimpleCov](https://github.com/colszowka/simplecov).

## Key Features

The primary goal of Coverband is giving deep insight into your production runtime usage of your application code, while having the least impact on performance possible.

* Low performance overhead
* Various controls from sampling, data collection rate, etc to further control performance
* Ignore directories to avoid overhead data collection on vendor, lib, etc.
* Development mode, offers deep insight of code usage details (number of LOC execution during single request, etc) during development.
* Easy setup for any Ruby Rack based web framework (Rails, Sinatra, etc)
* Allows for integration with any other Ruby application flows (background jobs, crons, scripts)

## Coverband Demo

Take Coverband for a spin on the live Heroku deployed [Coverband Demo](https://coverband-demo.herokuapp.com/). The [full source code for the demo](https://github.com/danmayer/coverband_demo) is available to help with configuration and understanding of basic usage.

# How To Use

Below is my Coverband workflow, which hopefully will help other best use this library.

* install coverband
* start your app and hit a few endpoints
* validate data collection and code coverage with  `rake coverband:coverage`
* test setup in development (hit endpoints and generate new report)
* deploy to staging and verify functionality
* deploy to production and verify functionality
* every 2 weeks or so, with major releases
   * clear old coverage: `rake coverband:clear`
   * deploy and verify coverage is matching expectations
* __COVERAGE DRIFT__
   * if you never clear you have lines of code drift from when they were recorded
   * if you clear on every deploy you don't capture as useful of data
   * there is a tradeoff on accuracy and data value
   * I recommend clearing after major code changes, significant releases, or some regular schedule.

## Example Output

Since Coverband is [Simplecov](https://github.com/colszowka/simplecov) output compatible it should work with any of the `SimpleCov::Formatter`'s available. The output below is produced using the default Simplecov HTML formatter.

Index Page
![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_index.png)

Details on a example Sinatra app
![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_details.png)


# Installation

Follow the below section to install and configure Coverband.

![coverband installation](https://raw.githubusercontent.com/danmayer/coverband/master/docs/coverband-install-resize.gif)

## Prerequisites

* Coverband requires Ruby 2.1 to run the older and slower implementation (TracePoint).
* Modern Coverband Ruby 2.3+ is recommended, this runs the (Coverage) implementation.

## Gem Installation

Add this line to your application's Gemfile:

```bash
gem 'coverband'
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install coverband
```

# Configuration

After you have the gem, you will want to setup the needed integration:

1. Coverband Config File Setup
2. Configure Rake
3. Insert Coverband Rack Middleware

### 1. Coverband Config File Setup

You need to configure cover band you can either do that passing in all configuration options to `Coverband.configure` in block format, or a simpler style is to call `Coverband.configure` with nothing while will load `config/coverband.rb` expecting it to configure the app correctly. Below is an example config file for a Rails 5 app:

```ruby
#config/coverband.rb
Coverband.configure do |config|
  config.root              = Dir.pwd
  config.collector         = 'coverage'
  config.redis             = Redis.new(url: ENV['REDIS_URL']) if defined? Redis
  # TODO NOTE THIS IS A ISSUE IN THE 2.0 release you set something like redis and the store
  # I need to look a bit more at this but got one bug report quickly after release
  # (even though test builds didnt need)
  config.store             = Redis.new(url: ENV['REDIS_URL']) if defined? Redis
  config.ignore            = %w[vendor .erb$ .slim$]
  # add paths that you deploy to that might be different than your local dev root path
  config.root_paths        = []

  # reporting frequency
  # if you are debugging changes to coverband I recommend setting to 100.0
  # otherwise it is find to report slowly over time with less performance impact
  # with the Coverage collector coverage is ALWAYS captured this is just how frequently
  # it is reported to your back end store.
  config.percentage        = Rails.env.production? ? 1.0 : 100.0
  config.logger            = Rails.logger

  # config options false, true, or 'debug'. Always use false in production
  # true and debug can give helpful and interesting code usage information
  # they both increase the performance overhead of the gem a little.
  # they can also help with initially debugging the installation.
  # config.verbose           = 'debug'
end
```

### 2. Configure Rake

Either add the below to your `Rakefile` or to a file included in your Rakefile such as `lib/tasks/coverband.rake` if you want to break it up that way.

```ruby
require 'coverband'
Coverband.configure
require 'coverband/tasks'
```
This should give you access to a number of Coverband tasks

```bash
rake -T coverband
rake coverband:clear         # reset coverband coverage data
rake coverband:coverage      # report runtime coverband code coverage
```

### 3. Configure Rack to use the Coverband middleware

The middleware is what makes Coverband gather metrics while a webapp app runs.

#### For Rails apps

There are a number of options for starting Coverband and when to insert it into your middleware stack. At the moment this is my recommendation, to ensure you capture usage data on any files required by other plugins.

Then add the middleware to your Rails rake middle ware stack:

```ruby
# config/application.rb
[...]

module MyApplication
  class Application < Rails::Application
    [...]

    # Coverband needs to be setup before any of the initializers to capture usage of them
    require 'coverband'
    Coverband.configure
    config.middleware.use Coverband::Middleware

    # if one uses before_eager_load as I did previously
    # any files that get loaded as part of railties will have no coverage
    config.before_initialize do
      require 'coverage'
      Coverband::Collectors::Base.instance.start
    end

  end
end
```

#### For Sinatra apps

For the best coverage you want this loaded as early as possible. I have been putting it directly in my `config.ru` but you could use an initializer, though you may end up missing some boot up coverage.

```ruby
require File.dirname(__FILE__) + '/config/environment'

require 'coverband'
Coverband.configure

use Coverband::Middleware
run ActionController::Dispatcher.new
```

# Verify Correct Installation

* boot up your application
* run `rake coverband:coverage` this will show app initialization coverage
* run app and hit a controller (hit at least +1 time over your `config.startup_delay` setting default is 0)
* run `rake coverband:coverage` and you should see coverage increasing for the endpoints you hit.

## Installation Script

These are the steps show in setting up coverband in the gif in the readme.

```
rails new coverage_example
cd coverage_example
atom .

# open Gemfile, add lines
gem 'redis'
gem 'coverband', '>= 2.0.0.alpha1', require: false

bundle install

# create config/coverband.rb
# copy the config from the readme
# If you don't set REDIS_URL, remove that to use default localhost

# Make some code so we can look at the coverage
rails generate scaffold blogs
rake db:migrate

# open Rakefile, add lines
require 'coverband'
Coverband.configure
require 'coverband/tasks'

# verify rake
rake -T coverband

# configure config/application.rb
# copy lines from readme

# start up your app
rake coverband:coverage
# view boot up coverage

rails s

open http://localhost:3000/blogs

# click around some to trigger usage

# view updated coverage
rake coverband:coverage
```

# Usage

### Example apps

- [Rails 5.1.x App](https://github.com/danmayer/coverage_rails_benchmark)
- [Sinatra app](https://github.com/danmayer/churn-site)
- [Non Rack Ruby app](https://github.com/danmayer/coverband_examples)

### View Coverage

You can view the report different ways, but the easiest is the Rake task which opens the SimpleCov formatted HTML.

`rake coverband:coverage`

This should auto-open in your browser, but if it doesn't the output file should be in `coverage/index.html`

### Clear Coverage

If your code has changed and your coverage line data doesn't seem to match run time. You probably need to clear your old line data... You will need to run this in the environment you wish to clear the data from.

`rake coverband:clear`

### Automated Clearing Line Coverage Data

After a deploy where code has changed significantly.

The line numbers previously recorded in Redis may no longer match the current state of the files.
If being slightly out of sync isn't as important as gathering data over a long period,
you can live with minor inconsistency for some files.

As often as you like or as part of a deploy hook you can clear the recorded Coverband data with the following command.

```ruby
# defaults to the currently configured Coverband.configuration.redis
Coverband::Reporter.clear_coverage
# or pass in the current target redis
Coverband::Reporter.clear_coverage(Redis.new(:host => 'target.com', :port => 6789))
```
You can also do this with the included rake tasks.

### Manual Configuration (for example for background jobs)

It is easy to use Coverband outside of a Rack environment. Make sure you configure Coverband in whatever environment you are using (such as `config/initializers/*.rb`). Then you can hook into before and after events to add coverage around background jobs, or for any non Rack code.

For example if you had a base Resque class, you could use the `before_perform` and `after_perform` hooks to add Coverband

```ruby
require 'coverband'
Coverband.configure

def before_perform(*args)
  if (rand * 100.0) <= Coverband.configuration.percentage
    @recording_samples = true
    Coverband::Base.instance.start
  else
    @recording_samples = false
  end
end

def after_perform(*args)
  if @recording_samples
    Coverband::Base.instance.stop
    Coverband::Base.instance.save
  end
end
```

In general you can run Coverband anywhere by using the lines below. This can be useful to wrap all cron jobs, background jobs, or other code run outside of web requests. I recommend trying to run both background and cron jobs at 100% coverage as the performance impact is less important and often old code hides around those jobs.


```ruby
require "coverband"
Coverband.configure

coverband = Coverband::Base.instance

#manual
coverband.start
coverband.stop
coverband.save

#sampling
coverband.sample {
  #code to sample coverband
}
```

### Manual Configuration (for cron jobs / Raketasks)

A question about [supporting cron jobs and Rake tasks](https://github.com/danmayer/coverband/issues/106) was asked by [@ndbroadbent](https://github.com/ndbroadbent), there are a couple ways to go about it including his good suggestion.

He extended the Coverband Rake tasks by adding `lib/tasks/coverband.rake` with support to wrap all Rake tasks with coverband support.

```
require 'coverband'
Coverband.configure
require 'coverband/tasks'

# Wrap all Rake tasks with Coverband
current_tasks = Rake.application.top_level_tasks
if current_tasks.any? && current_tasks.none? { |t| t.to_s.match?(/^coverband:/) }
  current_tasks.unshift 'coverband:start'
  current_tasks.push 'coverband:stop_and_save'
end

namespace :coverband do
  task :start do
    Coverband::Base.instance.start
  end

  task :stop_and_save do
    Coverband::Base.instance.stop
    Coverband::Base.instance.save
  end
end
```

That is a interesting approach and if you Run all your cron jobs as Rake tasks might work well for you. In a production application where we run Coverband, we run all of our Cron jobs with the `rails runner` script. We took this alternative approach which will wrap all runner jobs with Coverband recording, by creating `lib/railties/coverage_runner.rb`.

```
require 'rails'

# Capture code coverage during our cron jobs
class CoverageRunner < ::Rails::Railtie
  runner do
    Coverband::Collectors::Base.instance.start
    at_exit do
      Coverband::Collectors::Base.instance.report_coverage
    end
  end
end
```

### safe_reload_files: Forcing Coverband to Track Coverage on Files loaded during boot

The way Coverband is built it will record and report code usage in production for anything `required` or `loaded` after calling `Coverband.start`. This means some of Rails initial files and Gems are loaded before you can generally call `Coverband.start` for example if you use the `application.rb` to initialize and start Coverband, that file will be reported as having no coverage, as it can't possibly start Coverband before the file is loaded. 

The `safe_reload_files` reload option in the configuration options can help to ensure you can track any files you want regardless of them loading before Coverband. For example if I wanted to show the coverage of `config/coverband.rb` which has to be loaded before calling `Coverband.start` I could do that by adding that path to the `safe_reload_files` option.

```
Coverband.configure do |config|
  # ... a bunch of other options
  # using the new safe reload to enforce files loaded
  config.safe_reload_files = ['config/coverband.rb']
end
```
By adding any files above you will get reporting on those files as part of your coverage runtime report.


### Collecting Gem / Library Usage

By default Coverband has assumed you are trying to track your application code usage not all the supporting framework and library (Gems) code usage. There has been some good points and reasons folks want to track library usage, for example to find out which Gems they aren't actually using in production. See some of the discussion on [issue 21](https://github.com/danmayer/coverband/issues/21).

* Using the Tracepoint Collector
   * just make sure to set `Coverband.configuration.include_gems = true` in your config options
   * note by tracking all the additional usage this can have significant performance impacts of the Tracepoint implementation
* Using the Coverage Collector
   * use the `safe_reload_files` feature to add the path of all gem files you wish to track
   * --- or ---
   * ensure you call `Coverband.start` before loading all your gems
      * while possible this is currently hard as Rails and most environments load your whole Gemfile
      * looking for an improve and easier way to support this.  


### Verbose Debug / Development Mode

Note: To debug issues getting coverband working. I recommend running in development mode, by turning verbose logging on `config.verbose = true` and passing in the Rails.logger `config.logger = Rails.logger` to the Coverband config. This makes it easy to follow in development mode. Be careful to not leave these on in production as they will affect performance.

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

### Merge coverage data over time

If you are clearing data on every deploy. You might want to write the data out to a file first. Then you could merge the data into the final results later.

__note:__ I don't actually recommend clearing on every deploy, but only following significant releases where many line numbers would be off. If you follow that approach you don't need to merge data over time as this example shows how.

```ruby
data = JSON.generate Coverband::Reporter.get_current_scov_data
File.write("blah.json", data)
# Then later on, pass it in to the html reporter:
data = JSON.parse(File.read("blah.json"))
Coverband::Reporter.report :additional_scov_data => [data]
```

You can also pass a `:additional_scov_data => [data]` option to `Coverband::Reporter.get_current_scov_data` to write out merged data.

### Writing Coverband Results to S3

If you add some additional Coverband configuration your coverage html report will be written directly to S3, update `config/coverband.rb` like below.

```
  # configure S3 integration
  config.s3_bucket = 'coverband-demo'
  config.s3_region = 'us-east-1'
  config.s3_access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.s3_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
```

### Viewing / Hosting S3 Coverband results in app

Beyond writing to S3 you can host the S3 file with a build in Sintatra app in Coverband. Just configure your Rails route `config/routes.rb`

```
Rails.application.routes.draw do
  # ... lots of routes
  mount Coverband::S3Web, at: '/coverage'
end
```

__NOTE__: ADD PASSWORD PROTECTION OR YOU CAN EXPOSE ALL YOUR SOURCE CODE

It is easy to add some basic protect around the coverage data, below shows how you can use devise or basic auth, by adding a bit of code to your `config/routes.rb` file.

```
# protect with existing Rails devise configuration
devise_constraint = lambda do |request|
  request.env['warden'] && request.env['warden'].authenticate? && request.env['warden'].user.admin?
end

# protect with http basic auth
# curl --user foo:bar http://localhost:3000/coverage
basic_constraint = lambda do |request|
  return true if Rails.env.development?
  if ActionController::HttpAuthentication::Basic.has_basic_credentials?(request)
    credentials = ActionController::HttpAuthentication::Basic.decode_credentials(request)
    email, password = credentials.split(':')

    email == 'foo' && password = 'bar'
  end
end

Rails.application.routes.draw do
  # ... lots of routes
  constraints basic_constraint do
    mount Coverband::S3Web, at: '/coverage'
  end
end
```

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

* run tests: `rake`
* view test coverage: `open coverage/index.html`
* run the benchmarks before and after your change to see impact
   * `rake benchmarks` 

### Known Issues

* __total fail__ on front end code, because of the precompiled template step basically coverage doesn't work well for `erb`, `slim`, and the like.
  * related it will try to report something, but the line numbers reported for `ERB` files are often off and aren't considered useful. I recommend filtering out .erb using the `config.ignore` option. 
* If you have SimpleCov filters, you need to clear them prior to generating your coverage report. As the filters will be applied to Coverband as well and can often filter out everything we are recording.
* coverage doesn't show for Rails `config/application.rb` or `config/boot.rb` as they get loaded when loading the Rake environment prior to starting the `Coverage` library.

### Debugging Redis Store

What files have been synced to Redis?

`Coverband.configuration.store.covered_files`

What is the coverage data in Redis?

`Coverband.configuration.store.coverage`

### Internal Formats

If you are doing development having some documented examples of various internal data formats can be helpfu....

The format we get from TracePoint, Coverage, Internal Representations, and Used by SimpleCov for reporting have traditionally varied a bit. We can document the differences in formats here.

#### Coverage

```
>> require 'coverage'
=> true
>> Coverage.start
=> nil
>> require './test/unit/dog.rb'
=> true
>>  5.times { Dog.new.bark }
=> 5
>> Coverage.peek_result
=> {"/Users/danmayer/projects/coverband/test/unit/dog.rb"=>[nil, nil, 1, 1, 5, nil, nil]}
```

#### SimpleCov

The same format, but relative paths.

```
{"test/unit/dog.rb"=>[1, 2, nil, nil, nil, nil, nil]}
```

#### Redis Store

We store relative path in Redis, the Redis hash stores line numbers -> count (as strings).

```
# Array
["test/unit/dog.rb"]

# Hash
{"test/unit/dog.rb"=>{"1"=>"1", "2"=>"2"}}
```

#### File Store

Similar format to redis store, but array with integer values

```
{"test/unit/dog.rb"=>{"1"=>1, "2"=>2}}
```

# Future Coverband

### Alternative Redis formats

* Look at alternative storage formats for Redis
  * [redis bitmaps](http://blog.getspool.com/2011/11/29/fast-easy-realtime-metrics-using-redis-bitmaps/)
  * [redis bitfield](https://stackoverflow.com/questions/47100606/optimal-way-to-store-array-of-integers-in-redis-database)

### Todo

* rackup / how to run webapp via rake
  * move off sinatra to pure rack 
* graphite adapters (it would allow passing in date ranges on usage)
* perf test for array vs hash
* redis pipeline around hash (or batch get then push)
* move to SimpleCov console out, or make similar console tabular output
* Improve network performance by logging to files that purge later (like NR) (far more time lost in TracePoint than sending files, hence not a high priority, but would be cool)
* Add support for [zadd](http://redis.io/topics/data-types-intro) so one could determine single call versus multiple calls on a line, letting us determine the most executed code in production.
* Possibly add ability to record code run for a given route
* integrate recording with deploy tag or deploy timestamp
   *  diff code usage across deployed versions 
* Improve client code api, around manual usage of sampling (like event usage)
* ability to change the Coverband config at runtime by changing the config pushed to the Redis hash. In memory cache around the changes to only make that call periodically.
* Opposed to just showing code usage on a route allow 'tagging' events which would record line coverage for that tag (this would allow tagging all code that modified an ActiveRecord model for example
* support runner, active job, etc without needed extra config (improved railtie integration)

# Resources

These notes of kind of for myself, but if anyone is seriously interested in contributing to the project, these resources might be helpful. I learned a lot looking at various existing projects and open source code.

##### Ruby Std-lib Coverage

* [Ruby Coverage docs](https://ruby-doc.org/stdlib-2.5.0/libdoc/coverage/rdoc/Coverage.html)

##### Other

* [erb code coverage](http://stackoverflow.com/questions/13030909/how-to-test-code-coverage-for-rails-erb-templates)
* [more erb code coverage](https://github.com/colszowka/simplecov/issues/38)
* [erb syntax](http://stackoverflow.com/questions/7996695/rails-erb-syntax) parse out and mark lines as important
* [ruby 2 tracer](https://github.com/brightbox/deb-ruby2.0/blob/master/lib/tracer.rb)
* [coveralls hosted code coverage tracking](https://coveralls.io/docs/ruby) currently for test coverage but might be a good partner for production coverage
* [simplecov usage example](http://www.cakesolutions.net/teamblogs/brief-introduction-to-rspec-and-simplecov-for-ruby) copy some of the syntax sugar setup for cover band
* [Jruby coverage bug](https://github.com/jruby/jruby/issues/1196)
* [learn from oboe ruby code](https://github.com/appneta/oboe-ruby#writing-custom-instrumentation)
* [learn from stackprof](https://github.com/tmm1/stackprof#readme)
* I believe there are possible ways to get even better data using the new [Ruby2 TracePoint API](http://www.ruby-doc.org/core/TracePoint.html)

# License

This is a MIT License project...
See the file license.txt for copying permission.
