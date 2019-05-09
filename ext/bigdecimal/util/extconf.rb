# frozen_string_literal: false
require 'mkmf'
require 'pathname'

def check_bigdecimal_so
  checking_for(checking_message("bigdecimal.so")) do
    if RUBY_PLATFORM =~ /mswin/
      $DLDFLAGS << " -libpath:.."
      $libs << " bigdecimal-$(arch).lib"
      true
    else
      base_dir = Pathname("../../../..").expand_path(__FILE__)
      current_dir = Pathname.pwd.relative_path_from(base_dir)

      lib_dir = base_dir/"lib"
      bigdecimal_so = lib_dir/"bigdecimal.#{RbConfig::CONFIG['DLEXT']}"
      unless bigdecimal_so.exist?
        if RUBY_PLATFORM =~ /cygwin|mingw/
          tmp_build_base_dir = Pathname("tmp")/RUBY_PLATFORM/"bigdecimal"
          if current_dir == tmp_build_base_dir/"util"/RUBY_VERSION
            # For rake-compiler-dock
            ver = RUBY_VERSION.split('.')[0, 2].join('.')
            bigdecimal_so = lib_dir/ver/"bigdecimal.#{RbConfig::CONFIG['DLEXT']}"
          end
        end
        break false unless bigdecimal_so.exist?
      end
      $libs << " #{bigdecimal_so}"
      true
    end
  end
end

unless check_bigdecimal_so
  $stderr.puts "Unable to find bigdecimal.so"
  abort
end

create_makefile('bigdecimal/util')
