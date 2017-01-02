# Coverband

[![Build Status](https://travis-ci.org/danmayer/coverband.svg?branch=master)](https://travis-ci.org/danmayer/coverband)

A gem to measure production code usage, showing each line of code that is executed. Coverband allows easy configuration to collect and report on production code usage. It can be used as Rack middleware, wrapping a block with sampling, or manually configured to meet any need (like usage during background jobs). I like to think of this as production code coverage, but that implies test coverage to some folks, so being more explicit to say that it shows when a line of code is executed in a given environment is the most accurate way to describe it.

* Allow sampling to avoid the performance overhead on every request.
* Ignore directories to avoid overhead data collection on vendor, lib, etc.
* Take a baseline to get initial app execution during app initialization. (the baseline is important because some code is executed during app load, but might not be invoked during any requests, think prefetching, initial cache builds, setting constants, etc...)
* Development mode for additional code usage details (number of LOC execution during single request, etc).
* Coverband is not intended for test code coverage, for that just check out [SimpleCov](https://github.com/colszowka/simplecov).

__Notes:__ Latest versions of Coverband drop support for anything less than Ruby 2.0, and Ruby 2.1+ is recommended.

###### Success:
After running in production for 30 minutes, we were able very easily delete 2000 LOC after looking through the data. We expect to be able to clean up much more after it has collected more data.

###### Performance Impact

The performance impact on Ruby 2.1+ is fairly small and no longer requires a C-extension. Look at the benchmark rake task for specific details.

## Installation

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

That gives you the gem, but to get up and running then follow:

* [Coverband Configuration](https://github.com/danmayer/coverband#configuration)
  * Rake integration
  * Coverband config setup
  * Require Coverband
  * Insert middleware in stack  
* run `bundle exec rake coverband:baseline` ([what is baseline?](https://github.com/danmayer/coverband#coverband-baseline))
* run `bundle exec rake coverband:coverage` this will show app initialization coverage
* run app and hit a controller (hit at least +1 time over your `config.startup_delay` setting default is 2)
* run `bundle exec rake coverband:coverage` and you should see coverage increasing for the endpoints you hit.


## Example Output

Since Coverband is [Simplecov](https://github.com/colszowka/simplecov) output compatible it should work with any of the `SimpleCov::Formatter`'s available. The output below is produced using the default Simplecov HTML formatter.

Index Page
![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_index.png)

Details on a example Sinatra app
![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_details.png)

## Notes

* Coverband has been used on large scale production websites without large impacts on performance. Adjusting the sample rate to achieve an acceptable trade-off on detailed information vs performance impact. Coverband started as a Ruby 1.9 project and the performance impact has been reduced by each Ruby release since.

## Coverband Baseline

__TLDR:__ Baseline is app initialization coverage, not captured during runtime.

The baseline seems to cause some confusion. Basically, when Coverband records code usage, it will not request initial startup code like method definition, it covers what it hit during run time. This would produce a fairly odd view of code usage. To cover things like defining routes, dynamic methods, and the like Coverband records a baseline. The baseline should capture coverage of app initialization and boot up, we don't want to do this on deploy as it can be slow. So we take a recording of boot up as a one time baseline Rake task `bundle exec rake coverband:baseline`.

## Configuration

### 1. Create Coverband config file

You need to configure cover band you can either do that passing in all configuration options to `Coverband.configure` in block format, or a simpler style is to call `Coverband.configure` with nothing while will load `config/coverband.rb` expecting it to configure the app correctly. Below is an example config file for a Sinatra app:

```ruby
#config/coverband.rb
Coverband.configure do |config|
  config.root              = Dir.pwd
  if defined? Redis
    config.redis           = Redis.new(:host => 'redis.host.com', :port => 49182, :db => 1)
  end
  config.coverage_baseline = Coverband.parse_baseline
  config.root_paths        = ['/app/'] # /app/ is needed for heroku deployments
  # regex paths can help if you are seeing files duplicated for each capistrano deployment release
  #config.root_paths       = ['/server/apps/my_app/releases/\d+/']
  config.ignore            = ['vendor','lib/scrazy_i18n_patch_thats_hit_all_the_time.rb']
  # Since rails and other frameworks lazy load code. I have found it is bad to allow
  # initial requests to record with coverband. This ignores first 15 requests
  # NOTE: If you are using a threaded webserver (example: Puma) this will ignore requests for each thread
  config.startup_delay     = Rails.env.production? ? 15 : 2
  # Percentage of requests recorded
  config.percentage        = Rails.env.production? ? 30.0 : 100.0

  config.logger            = Rails.logger

  #stats help you collect how often you are sampling requests and other info
  if defined? Statsd
    config.stats           = Statsd.new('statsd.host.com', 8125)
  end
  # config options false, true, or 'debug'. Always use false in production
  # true and debug can give helpful and interesting code usage information
  # they both increase the performance overhead of the gem a little.
  # they can also help with initially debugging the installation.
  config.verbose           = Rails.env.production? ? false : true
end
```

### 2. Configuring Rake

Either add the below to your `Rakefile` or to a file included in your Rakefile such as `lib/tasks/coverband.rake` if you want to break it up that way.

```ruby
require 'coverband'
Coverband.configure
require 'coverband/tasks'
```
This should give you access to a number of cover band tasks

```bash
bundle exec rake -T coverband
rake coverband:baseline      # record coverband coverage baseline
rake coverband:clear         # reset coverband coverage data
rake coverband:coverage      # report runtime coverband code coverage
```

The default Coverband baseline task will try to detect your app as either Rack or Rails environment. It will load the app to take a baseline reading. The baseline coverage is important because some code is executed during app load, but might not be invoked during any requests, think prefetching, initial cache builds, setting constants, etc. If the baseline task doesn't load your app well you can override the default baseline to create a better baseline yourself. Below for example is how I take a baseline on a pretty simple Sinatra app.

```ruby
namespace :coverband do
  desc "get coverage baseline"
  task :baseline_app do
    Coverband::Reporter.baseline {
      require 'sinatra'
      require './app.rb'
    }
  end
end
```

To verify that rake is working run `rake coverband:baseline`
then run `rake coverband:coverage` to view what your baseline coverage looks like before any runtime traffic has been recorded.

### 3. Configure Rack to use the Coverband middleware

The middleware is what makes Coverband gather metrics when your app runs.
I setup Coverband in my rackup `config.ru` you can also set it up in rails middleware, but it may miss recording some code coverage early in the rails process. It does improve performance to have it later in the middleware stack. So there is a tradeoff there.

#### For Sinatra apps

For the best coverage you want this loaded as early as possible. I have been putting it directly in my `config.ru` but you could use an initializer, though you may end up missing some boot up coverage.

```ruby
require File.dirname(__FILE__) + '/config/environment'

require 'coverband'
Coverband.configure

use Coverband::Middleware
run ActionController::Dispatcher.new
```

#### For Rails apps

Create an initializers file

```ruby
# config/initializers/coverband_middleware.rb

# Configure the Coverband Middleware
require 'coverband'
Coverband.configure
```

Then add the middleware to your Rails rake middle ware stack:

```ruby
# config/application.rb
[...]

module MyApplication
  class Application < Rails::Application
    [...]

    # Coverband use Middleware
    config.middleware.use Coverband::Middleware

  end
end
```

Note: To debug in development mode, I recommend turning verbose logging on `config.verbose = true` and passing in the Rails.logger `config.logger = Rails.logger` to the Coverband config. This makes it easy to follow in development mode. Be careful to not leave these on in production as they will affect performance.

## Usage

1. Start your server with `rails s` or `rackup config.ru`.
2. Hit your development server exercising the endpoints you want to verify Coverband is recording (you should see debug outputs in your server console)
3. Run `rake coverband:coverage` again, previously it should have only shown the baseline data of your app initializing. After using it in development it should show increased coverage from the actions you have exercised.

Note: if you use `rails s` and data aren't recorded, make sure it is using your `config.ru`.

## Example apps

- [Rails app](https://github.com/arnlen/rails-coverband-example-app)
- [Rails app with Coverband 1.1](https://github.com/danmayer/covered_rails)
- [Sinatra app](https://github.com/danmayer/churn-site)
- [Non rack ruby app](https://github.com/danmayer/coverband_examples)

### Manual configuration (for example for background jobs)

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

### Clearing Line Coverage Data

After a deploy where code has changed.
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


### Verbose debug mode for development

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

### Coverband development

If you are working on adding features, PRs, or bugfixes to Coverband this section should help get you going.

* run tests: `bundle exec rake`
* view test coverage: `open coverage/index.html`
* run the benchmarks before and after your change to see impact
   * `bundle exec rake benchmarks` 

### Known issues

* __total fail__ on front end code, because of the precompiled template step basically coverage doesn't work well for `erb`, `slim`, and the like.
* If you don't have a baseline recorded your coverage can look odd like you are missing a bunch of data. It would be good if Coverband gave a more actionable warning in this situation.
* If you have SimpleCov filters, you need to clear them prior to generating your coverage report. As the filters will be applied to Coverband as well and can often filter out everything we are recording.
* the line numbers reported for `ERB` files are often off and aren't considered useful. I recommend filtering out .erb using the `config.ignore` option.

## TODO

* move to SimpleCov console out, or make similar console tabular output
* Fix network performance by logging to files that purge later (like NR) (far more time lost in TracePoint than sending files, hence not a high priority, but would be cool)
* Add support for [zadd](http://redis.io/topics/data-types-intro) so one could determine single call versus multiple calls on a line, letting us determine the most executed code in production.
* Possibly add ability to record code run for a given route
* Improve client code api, around manual usage of sampling (like event usage)
* Provide a better lighter example app, to show how to use Coverband.
  * blank rails app
  * blank Sinatra app
* report on Coverband files that haven't recorded any coverage (find things like events and crons that aren't recording, or dead files)
* ability to change the Coverband config at runtime by changing the config pushed to the Redis hash. In memory cache around the changes to only make that call periodically.
* Opposed to just showing code usage on a route allow 'tagging' events which would record line coverage for that tag (this would allow tagging all code that modified an ActiveRecord model for example
* mountable rack app to view coverage similar to flipper-ui

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Make sure all tests are passing (run `bundle install`, make sure Redis is running, and then execute `bundle exec rake test`)
6. Create new Pull Request

## Resources

These notes of kind of for myself, but if anyone is seriously interested in contributing to the project, these resources might be helpful. I learned a lot looking at various existing projects and open source code.

##### Ruby Std-lib Coverage

* [Fixed bug causing segfaults on 1.9.X](https://www.ruby-forum.com/topic/1811306)
* [Current Coverage Bug causing issues on 2.1.1](https://bugs.ruby-lang.org/issues/9572)
* [Ruby Coverage docs](http://www.ruby-doc.org/stdlib-1.9.3/libdoc/coverage/rdoc/Coverage.html)

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

## MIT License
See the file license.txt for copying permission.
