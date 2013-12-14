# Coverband

Rack middleware to measure production code coverage. Coverband allows easy configuration to collect and report on production code coverage.

* Allow sampleing to avoid the perf overhead on every request.
* Ignore directories to avoid overhead data collection on vendor, lib, etc
* Take a baseline to get inital app loading coverage.

At the momement, Coverband relies on Ruby's `set_trace_func` hook. I attempted to use the standard lib's `Coverage` support but it proved buggy when stampling or stoping and starting collection. When [Coverage is patched](https://www.ruby-forum.com/topic/1811306) in future Ruby versions it would likely be better. Using `set_trace_func` has some limitations where it doesn't collect covered lines, but I have been impressed with the coverage it shows for both Sinatra and Rails applications.

###### Success:
After running in production for 30 minutes, we were able very easily delete 2000 LOC after looking through the data. We expect to be able to clean up much more after it has collected more data.

## Installation

Add this line to your application's Gemfile:

    gem 'coverband'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install coverband

## Example Output

Index Page
![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_index.png)

Details on a example Sinatra app
![image](https://raw.github.com/danmayer/coverband/master/docs/coverband_details.png)

## Notes

* Using Redis 2.x gem, while supported is extremely slow and not recommended. It will have a much larger impact on overhead performance.
* This has been tested in Ruby 1.9.3, 2 and is running in production on Sinatra, Rails 2.3.x, and Rails 3.2.x
* No 1.8.7 support
* There is a performance impact which is why the gem supports sampling. On low traffic sites I am running a sample rake of 20% and on very high traffic sites I am sampling at 1% which still gives excellent data
* I believe there are possible ways to get even better data using the new Ruby2 TracePoint API
* Make sure to add any folders you want to ignore like `vendor` and possibly `lib` as it can help to reduce performance overhead.

## Usage

After installing the gem you likely want to get the rake tasks configured as well as the rack middle ware.

#### Configuring Rake

Either add the below to your `Rakefile` or to a file included in you Rakefile

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
	  baseline = JSON.parse(File.read('./tmp/coverband_baseline.json'))

	  root_paths = ['/app/']
	  coverband_options = {:existing_coverage => baseline, :roots => root_paths}
	  Coverband::Reporter.report(Redis.new, coverband_options)
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
    
#### Configure rack middleware

For the best coverage you want this loaded as early as possible. I have been putting it directly in my `config.ru` but you could use an initializer you may just end up missing some boot up coverage.

	require File.dirname(__FILE__) + '/config/environment'
	
	require 'coverband'
	
	Coverband.configure do |config|
	  config.root              = Dir.pwd
	  config.redis             = Redis.new
	  config.coverage_baseline = JSON.parse(File.read('./tmp/coverband_baseline.json'))
	  config.root_paths        = ['/app/']
	  config.ignore            = ['vendor']
	  config.percentage        = 100.0
	end

	use Coverband::Middleware
	run ActionController::Dispatcher.new


## TODO

* Improve the configuration flow (only one time redis setup etc)
  * a suggestion was a .coverband file which stores the config block (can't use initializers because we try to load before rails) 
* Fix performance by logging to files that purge later
* Add support for zadd http://redis.io/topics/data-types-intro so one could determine single hits versus multiple hits on a line. Letting us determine the most executed code in production.
* Add stats support on the number of requests recorded
* Possibly add ability to record code run for a given route

## Completed

* fix issue if a file can't be found for reporting
* add support for file matching ignore for example we need to ignore '/app/vendor/'
  * fix issue on heroku where it logs non app files
* Allow more configs to be passed in like percentage

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

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## MIT License
See the file license.txt for copying permission.
