# Coverband

Rack middleware to help measure production code coverage

## Installation

Add this line to your application's Gemfile:

    gem 'coverband'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install coverband

## Usage

TODO: Write usage instructions here

## TODO

* improve the configuration flow (only one time redis setup etc)
* fix performance by logging to files that purge later

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

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
