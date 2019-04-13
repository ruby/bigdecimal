# frozen_string_literal: false
require 'mkmf'
require 'pathname'

checking_for(checking_message("bigdecimal.so")) do
  if RUBY_PLATFORM =~ /mswin/
    $DLDFLAGS << " -libpath:.."
    $libs << " bigdecimal-$(arch).lib"
    true
  else
    base_dir = Pathname("../../../..").expand_path(__FILE__)
    current_dir = Pathname.pwd.relative_path_from(base_dir)

    tmp_build_base_dir = Pathname("tmp")/RUBY_PLATFORM/"bigdecimal"
    if current_dir == tmp_build_base_dir/"util"/RUBY_VERSION
      lib_dir = base_dir/"lib"
      bigdecimal_so = lib_dir/"bigdecimal.#{RbConfig::CONFIG['DLEXT']}"
      break false unless bigdecimal_so.exist?
      $libs << " #{bigdecimal_so}"
    else
      $libs << " $(TARGET_SO_DIR)../bigdecimal.so"
    end
    true
  end
end

create_makefile('bigdecimal/util')
