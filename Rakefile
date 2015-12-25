require "bundler/gem_tasks"
require "rake"
require "rake/extensiontask"
require "rake/testtask"

Rake::ExtensionTask.new('bigdecimal')

Rake::TestTask.new do |t|
  t.libs << 'test/lib'
  t.warning = true
end

task travis: :test
task test: :compile
