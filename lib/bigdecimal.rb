begin
  require "#{RUBY_VERSION[/\d+\.\d+/]}/bigdecimal.so"
rescue LoadError
  require 'bigdecimal.so'
end

def BigDecimal.new(*args, **kwargs)
  BigDecimal(*args, **kwargs)
end
