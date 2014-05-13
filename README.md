# Coverband

A gem to measure production code coverage. Coverband allows easy configuration to collect and report on production code coverage. It can be used as Rack middleware, wrapping a block with sampling, or manually configured to meet any need (like coverage on background jobs).

* Allow sampling to avoid the performance overhead on every request.
* Ignore directories to avoid overhead data collection on vendor, lib, etc.
* Take a baseline to get initial app loading coverage.

At the moment, Coverband relies on Ruby's `set_trace_func` hook. I attempted to use the standard lib's `Coverage` support but it proved buggy when sampling or stoping and starting collection. When [Coverage is patched](https://www.ruby-forum.com/topic/1811306) in future Ruby versions it would likely be better. Using `set_trace_func` has some limitations where it doesn't collect covered lines, but I have been impressed with the coverage it shows for both Sinatra and Rails applications.

###### Success:
After running in production for 30 minutes, we were able very easily delete 2000 LOC after looking through the data. We expect to be able to clean up much more after it has collected more data. 

This has now been running in production on many applications for months. I will clean up configurations, documentation, and strive to get a 1.0 release out soon.

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

## Example Output

Since Coverband is [Simplecov](https://github.com/colszowka/simplecov) output compatible it should work with any of the `SimpleCov::Formatter`'s available. The output below is produced using the default Simplecov HTML formatter. 

Index Page
![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_index.png)

Details on a example Sinatra app
![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_details.png)

## Notes

* Using Redis 2.x gem, while supported, is extremely slow and not recommended. It will have a much larger impact on overhead performance.
* This has been tested in Ruby 1.9.3, 2 and is running in production on Sinatra, Rails 2.3.x, and Rails 3.2.x
* No 1.8.7 support
* There is a performance impact which is why the gem supports sampling. On low traffic sites I am running a sample rake of 20% and on very high traffic sites I am sampling at 1%, which still gives excellent data
* I believe there are possible ways to get even better data using the new [Ruby2 TracePoint API](http://www.ruby-doc.org/core/TracePoint.html)
* Make sure to ignore any folders like `vendor` and possibly `lib` as it can help reduce performance overhead

## Usage

After installing the gem. There are a few steps to gather data, view reports, and for cleaning up the data.

1. First configure cover band options using the config file, See the section below
2. Then configure Rake, with helpful tasks. Make sure things are working by recording your Coverband baseline. See the section below
3. Setup the rack middleware, the middleware is what makes Coverband gather metrics when your app runs. See below for details
	* I setup Coverband in my rackup `config.ru` you can also set it up in rails middleware, but it may miss recording some code coverage early in the rails process. It does improve performance to have it later in the middleware stack. So there is a tradeoff there.
	* To debug in development mode, I recommend turning verbose logging on `config.verbose           = true` and passing in the Rails.logger `config.logger = Rails.logger` to the Coverband config. This makes it easy to follow in development mode. Be careful to not leave these on in production as they will effect performance.
4. Start your server with `rackup config.ru` If you use `rails s` make sure it is using your `config.ru` or Coverband won't be recording any data. 
5. Hit your development server exercising the endpoints you want to verify Coverband is recording.
6. Now to view changes in live coverage run `rake coverband:coverage` again, previously it should have only shown the baseline data of your app initializing. After using it in development it should show increased coverage from the actions you have exercised.

#### Configure Coverband Options

You need to configure cover band you can either do that passing in all configuration options to `Coverband.configure` in block format, or a much simpler style is to call `Coverband.configure` with nothing while will load `config/coverband.rb` expecting it to configure the app correctly. Below is an example config file for a Sinatra app:

```ruby
require 'json'

baseline = Coverband.parse_baseline

Coverband.configure do |config|
  config.root              = Dir.pwd
  if defined? Redis
    config.redis             = Redis.new(:host => 'redis.host.com', :port => 49182, :db => 1)
  end
  config.coverage_baseline = baseline
  config.root_paths        = ['/app/']
  config.ignore            = ['vendor']
  # Since rails and other frameworks lazy load code. I have found it is bad to allow
  # initial requests to record with coverband. This ignores first 15 requests
  config.startup_delay     = 15
  config.percentage        = 60.0
  if defined? Statsd
    config.stats             = Statsd.new('statsd.host.com', 8125)
  end
  config.verbose           = Rails.env.production? ? false : true
end
```

Here is a alternative configuration example, allowing for production and development settings:

```ruby
Coverband.configure do |config|
  config.root              = Dir.pwd
  config.redis             = Redis.new
  config.coverage_baseline = JSON.parse(File.read('./tmp/coverband_baseline.json'))
  config.root_paths        = ['/app/']
  config.ignore            = ['vendor']
  config.startup_delay     = Rails.env.production? ? 10 : 1
  config.percentage        = Rails.env.production? ? 15.0 : 100.0
end
```

#### Configuring Rake

Either add the below to your `Rakefile` or to a file included in your Rakefile such as `lib/tasks/coverband` if you want to break it up that way.

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

The default Coverband baseline task will try to load the Rails environment. For a non Rails application you can make your own baseline. Below for example is how I take a baseline on a Sinatra app.

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

To verify that rake is working run `rake coverband:baseline` and then run `rake coverband:coverage` to view what your baseline coverage looks like before any runtime traffic has been recorded.
    
#### Configure rack middleware

For the best coverage you want this loaded as early as possible. I have been putting it directly in my `config.ru` but you could use an initializer, though you may end up missing some boot up coverage.

```ruby
require File.dirname(__FILE__) + '/config/environment'
	
require 'coverband'
Coverband.configure

use Coverband::Middleware
run ActionController::Dispatcher.new
```
	
#### Configure Manually (for example for background jobs)

It is easy to use Coverband outside of a Rack environment. Make sure you configure Coverband in whatever environment you are using (such as `config/initializers/*.rb`). Then you can hook into before and after events to add coverage around background jobs, or for any non Rack code.

For example if you had a base Resque class, you could use the `before_perform` and `after_perform` hooks to add Coverband

```ruby
def before_perform(*args)
  if (rand * 100.0) > Coverband.configuration.percentage
    @@coverband ||= Coverband::Base.new
    @recording_samples = true
    @@coverband.start
  else
    @recording_samples = false
  end
end
      
def after_perform(*args)
  if @recording_samples
    @@coverband.stop
    @@coverband.save
  end
end
```

In general you can run Coverband anywhere by using the lines below

```ruby
require 'coverband'
	
Coverband.configure do |config|
  config.redis             = Redis.new
  config.percentage        = 50.0
end
  
coverband = Coverband::Base.new
    
#manual
coverband.start
coverband.stop
coverband.save
    
#sampling
coverband.sample {
  #code to sample coverband
}
```
 
## Clearing Line Coverage Data

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


## TODO

* Fix performance by logging to files that purge later (more time lost in set_trace_func than sending files)
* Add support for [zadd](http://redis.io/topics/data-types-intro) so one could determine single call versus multiple calls on a line, letting us determine the most executed code in production.
* Possibly add ability to record code run for a given route
* Improve client code api, around manual usage of sampling (like event usage)
* Provide a better lighter example app, to show how to use Coverband.
  * blank rails app
  * blank Sinatra app 

## Resources

* [erb code coverage](http://stackoverflow.com/questions/13030909/how-to-test-code-coverage-for-rails-erb-templates)
* [more erb code coverage](https://github.com/colszowka/simplecov/issues/38)
* [erb syntax](http://stackoverflow.com/questions/7996695/rails-erb-syntax) parse out and mark lines as important
* [ruby 2 tracer](https://github.com/brightbox/deb-ruby2.0/blob/master/lib/tracer.rb)
* [coveralls hosted code coverage tracking](https://coveralls.io/docs/ruby) currently for test coverage but might be a good partner for production coverage
* [bug in Ruby's stl-lib Coverage, needs to be fixed to be more accurate](https://www.ruby-forum.com/topic/1811306)
* [Ruby Coverage docs](http://www.ruby-doc.org/stdlib-1.9.3/libdoc/coverage/rdoc/Coverage.html)
* [simplecov walk through](http://www.tamingthemindmonkey.com/2011/09/27/ruby-code-coverage-using-simplecov) copy some of the syntax sugar setup for cover band
* [Jruby coverage bug](http://jira.codehaus.org/browse/JRUBY-6106?page=com.atlassian.jira.plugin.system.issuetabpanels:changehistory-tabpanel)
* [learn from oboe ruby code](https://github.com/appneta/oboe-ruby#writing-custom-instrumentation)
* [learn from stackprof](https://github.com/tmm1/stackprof#readme)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## MIT License
See the file license.txt for copying permission.
