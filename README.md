# Coverband

A gem to measure production code coverage. Coverband allows easy configuration to collect and report on production code coverage. It can be used as Rack middleware, wrapping a block with sampling, or manually configured to meet any need (like coverage on background jobs).

* Allow sampling to avoid the performance overhead on every request.
* Ignore directories to avoid overhead data collection on vendor, lib, etc.
* Take a baseline to get inital app loading coverage.

At the momement, Coverband relies on Ruby's `set_trace_func` hook. I attempted to use the standard lib's `Coverage` support but it proved buggy when stampling or stoping and starting collection. When [Coverage is patched](https://www.ruby-forum.com/topic/1811306) in future Ruby versions it would likely be better. Using `set_trace_func` has some limitations where it doesn't collect covered lines, but I have been impressed with the coverage it shows for both Sinatra and Rails applications.

###### Success:
After running in production for 30 minutes, we were able very easily delete 2000 LOC after looking through the data. We expect to be able to clean up much more after it has collected more data.

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

Since Coverband is [Simplecov](https://github.com/colszowka/simplecov) output compatible it should work with any of the `SimpleCov::Formatter`'s available. The output below is produced using the default Simplecov HTML formater. 

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

After installing the gem. There are a few steps to gather data, view reports, and cleaing up the data.

1. First configure Rake, with helpful tasks. See the section below
	* `rake coverband_baseline` helps you to record a baseline of your apps initialization process
	*  `rake coverband` after you have setup coverband on a server and started recording data this generates the report and opens it in your browser.
2. Setup the rack middleware, the middleware is what makes coverband gather metrics when your app runs. See below for details
	* I setup coverband in my rackup `config.ru` you can also set it up in rails middleware, but it may miss recording some code coverage early in the rails process. It does improve performance to have it later in the middleware stack. So there is a tradeoff there.
	* To debug in development mode, I recommend turning verbose logging on `config.verbose           = true` and passing in the Rails.logger `config.logger = Rails.logger` to the coverband config. This makes it easy to follow in development mode. Be careful to not leave these on in production as they will effect performance.
3. Start your server with `rackup config.ru` If you use `rails s` make sure it is using your `config.ru` or coverband won't be recording any data. 
4. Hit your development server exercising the endpoints you want to verify Coverband is recording.
5. Now to view changes in live coverage run `rake coverband` again, previously it should have only shown the baseline data of your app initializing. After using it in development it hsould show increased coverage from the actions you have exercised.

#### Configuring Rake

Either add the below to your `Rakefile` or to a file included in your Rakefile

```ruby
require 'coverband'
Coverband.configure do |config|
  config.redis             = Redis.new
  # merge in lines to consider covered manually to override any misses
  # existing_coverage = {'./cover_band_server/app.rb' => Array.new(31,1)}
  # JSON.parse(File.read('./tmp/coverband_baseline.json')).merge(existing_coverage) 
  config.coverage_baseline = JSON.parse(File.read('./tmp/coverband_baseline.json'))
  config.root_paths        = ['/app/']
  config.ignore            = ['vendor']
end

desc "report unused lines"
  task :coverband => :environment do
  Coverband::Reporter
end
	
desc "get coverage baseline"
task :coverband_baseline do
  Coverband::Reporter.baseline {
    #rails
    require File.expand_path("../config/environment", __FILE__)
    #sinatra
    #require File.expand_path("./app", __FILE__)
  }
end
```
    
#### Configure rack middleware

For the best coverage you want this loaded as early as possible. I have been putting it directly in my `config.ru` but you could use an initializer, though you may end up missing some boot up coverage.

```ruby
require File.dirname(__FILE__) + '/config/environment'
	
require 'coverband'

Coverband.configure do |config|
  config.root              = Dir.pwd
  config.redis             = Redis.new
  config.coverage_baseline = JSON.parse(File.read('./tmp/coverband_baseline.json'))
  config.root_paths        = ['/app/']
  config.ignore            = ['vendor']
  # Since rails and other frameworks lazy load code. I have found it is bad to allow
  # initial requests to record with coverband.
  # This allows 10 requests prior to trying to record any activitly.
  config.startup_delay     = 10
  config.percentage        = 15.0
end

use Coverband::Middleware
run ActionController::Dispatcher.new
```
	
#### Configure Manually (for example for background jobs)

It is easy to use coverband outside of a Rack environment. Make sure you configure coverband in whatever environment you are using (such as `config/initializers/*.rb`). Then you can hook into before and after events to add coverage around background jobs, or for any non Rack code.

For example if you had a base resque class, you could use the `before_perform` and `after_perform` hooks to add Coverband

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

In general you can run coverband anywhere by using the lines below

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
The line numbers previously recorded in redis may no longer match the curernt state of the files. 
If being slightly out of sync isn't as important as gathering data over a long period, 
you can live with minor inconsistancy for some files.

As often as you like or as part of a deploy hook you can clear the recorded coverband data with the following command.

```ruby
# defaults to the currently configured Coverband.configuration.redis
Coverband::Reporter.clear_coverage
# or pass in the current target redis
Coverband::Reporter.clear_coverage(Redis.new(:host => 'target.com', :port => 6789))
```

## TODO

* Improve the configuration flow (only one time redis setup etc)
  * a suggestion was a .coverband file which stores the config block (can't use initializers because we try to load before rails)
  * this is a bit crazy at the moment
* Fix performance by logging to files that purge later
* Add support for [zadd](http://redis.io/topics/data-types-intro) so one could determine single hits versus multiple hits on a line, letting us determine the most executed code in production.
* Add stats optional support on the number of total requests recorded
* Possibly add ability to record code run for a given route
* Add default rake tasks so a project could just require the rake tasks
* Improve client code api, particularly around configuration, but also around manual usage of sampling
* Provide a better lighter example app, to show how to use coverband.

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
