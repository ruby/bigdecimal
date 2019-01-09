begin
  require "#{RUBY_VERSION[/\d+\.\d+/]}/bigdecimal.so"
rescue LoadError
  require 'bigdecimal.so'
end

class BigDecimal
  module Deprecation
    def new(*args, **kwargs)
      warn "BigDecimal.new is deprecated; use BigDecimal() method instead.", uplevel: 1
      super
    end
  end

  class << self
    prepend Deprecation

    def inherited(subclass)
      warn "subclassing BigDecimal will be disallowed after bigdecimal version 2.0", uplevel: 1
    end
  end
end
