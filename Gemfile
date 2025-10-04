source 'https://rubygems.org'

gemspec

gem "benchmark_driver"
gem "fiddle", platform: :ruby
gem "rake", ">= 12.3.3"
gem "rake-compiler", ">= 0.9"
gem "minitest", "< 5.0.0"
gem "irb"
gem "test-unit"
if RUBY_ENGINE == "ruby" and RUBY_VERSION >= "3.2"
  gem "test-unit-ruby-core", github: "ruby/test-unit-ruby-core", branch: "master"
else
  # 1.0.7 is broken with ruby 3.2 and earlier
  gem "test-unit-ruby-core", "= 1.0.6"
end
