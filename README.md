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

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
