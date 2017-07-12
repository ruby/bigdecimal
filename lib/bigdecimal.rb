begin
  require "#{RUBY_VERSION[/\d+\.\d+/]}/bigdecimal.so"
rescue LoadError
  require 'bigdecimal.so'
end
