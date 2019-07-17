require "bundler"
Bundler::GemHelper.install_tasks

require "rake"
require "rake/extensiontask"
require "rake/testtask"

spec = eval(File.read('bigdecimal.gemspec'))
Rake::ExtensionTask.new('bigdecimal', spec)

Rake::TestTask.new do |t|
  t.libs << 'test/lib'
  t.test_files = FileList['test/bigdecimal/**/test_*.rb']
  t.warning = true
end

task travis: :test
task test: :compile
