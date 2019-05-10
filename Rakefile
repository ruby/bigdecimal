require "bundler"
Bundler::GemHelper.install_tasks

require "rake"
require "rake/extensiontask"
require "rake/testtask"

spec = eval(File.read('bigdecimal.gemspec'))
Rake::ExtensionTask.new('bigdecimal', spec) do |ext|
  ext.lib_dir = File.join(*['lib', ENV['FAT_DIR']].compact)
  ext.cross_compile = true
  ext.cross_platform = %w[x86-mingw32 x64-mingw32]
  ext.cross_compiling do |s|
    s.files.concat ["lib/2.3/bigdecimal.so", "lib/2.4/bigdecimal.so", "lib/2.5/bigdecimal.so"]
  end
end

desc "Compile binaries for mingw platform using rake-compiler-dock"
task 'build:mingw' do
  require 'rake_compiler_dock'
  RakeCompilerDock.sh "bundle && rake cross native gem RUBY_CC_VERSION=2.4.2:2.3.0:2.5.0"
end

Rake::TestTask.new do |t|
  t.libs << 'test/lib'
  t.test_files = FileList['test/bigdecimal/**/test_*.rb']
  t.warning = true
end

task travis: :test
task test: :compile
