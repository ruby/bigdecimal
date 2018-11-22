# frozen_string_literal: false
require 'mkmf'

def windows_platform?
  /cygwin|mingw|mswin/ === RUBY_PLATFORM
end

checking_for(checking_message("Windows")) do
  if windows_platform?
    base_dir = File.expand_path('../../../..', __FILE__)
    build_dir = File.join(base_dir, "tmp", RUBY_PLATFORM, "bigdecimal", RUBY_VERSION)
    library_base_name = "ruby-bigdecimal"
    case RUBY_PLATFORM
    when /cygwin|mingw/
      $LDFLAGS << " -L#{build_dir}"
      $libs << " -l#{library_base_name}"
    when /mswin/
      $DLDFLAGS << " /libpath:#{build_dir}"
      $libs << " lib#{library_base_name}.lib"
    end
    true
  else
    false
  end
end

create_makefile('util')
