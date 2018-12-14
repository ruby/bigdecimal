begin
  require "#{RUBY_VERSION[/\d+\.\d+/]}/bigdecimal.so"
rescue LoadError
  require 'bigdecimal.so'
end

def BigDecimal.new(*args, **kwargs)
  warn "BigDecimal.new is deprecated; use BigDecimal() method instead.", uplevel: 1
  BigDecimal(*args, **kwargs)
end
