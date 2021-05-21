# BigDecimal

![CI](https://github.com/ruby/bigdecimal/workflows/CI/badge.svg?branch=master&event=push)

BigDecimal provides an arbitrary-precision decimal floating-point number class.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bigdecimal'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install bigdecimal

### For RubyInstaller users

If your Ruby comes from [RubyInstaller](https://rubyinstaller.org/), make sure [Devkit](https://github.com/oneclick/rubyinstaller/wiki/Development-Kit) is available on your environment before installing bigdecimal.

### For Chocolatey

I don't have enough knowledge about Chocolatey.  Please tell me what should I write here.

## Which version should you select

The differences among versions are given below:

| version | characteristics | Supported ruby version range |
| ------- | --------------- | ----------------------- |
| 3.0.0   | You can use BigDecimal with Ractor on Ruby 3.0 | 2.5 .. |
| 2.0.x   | You cannot use BigDecimal.new and do subclassing | 2.4 .. |
| 1.4.x   | BigDecimal.new and subclassing always prints warning. | 2.3 .. 2.7 |
| 1.3.5   | You can use BigDecimal.new and subclassing without warning | .. 2.5 |

You can select the version you want to use using `gem` method in Gemfile or scripts.
For example, you want to stick bigdecimal version 1.3.5, it works file to put the following `gem` call in you Gemfile.

```ruby
gem 'bigdecimal', '1.3.5'
```

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `rake spec` to run the tests.
You can also run `bin/console` for an interactive prompt that
will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`,
and then run `bundle exec rake release`,
which will create a git tag for the version, push git commits and tags,
and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ruby/bigdecimal.

## License

BigDecimal is released under the Ruby and 2-clause BSD licenses.
See LICENSE.txt for details.
