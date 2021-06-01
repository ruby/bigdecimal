require "bundler"
Bundler::GemHelper.install_tasks

require "rake"
require "rake/extensiontask"
require "rake/testtask"

spec = eval(File.read('bigdecimal.gemspec'))
Rake::ExtensionTask.new('bigdecimal', spec)

Rake::TestTask.new do |t|
  t.libs << 'test/lib'
  t.ruby_opts << '-rhelper'
  t.test_files = FileList['test/bigdecimal/**/test_*.rb']
  t.warning = true
end

task travis: :test
task test: :compile

benchmark_tasks = []
namespace :benchmark do
  Dir.glob("benchmark/*.yml") do |benchmark|
    name = File.basename(benchmark, ".*")
    env = {
      "RUBYLIB" => nil,
      "BUNDLER_ORIG_RUBYLIB" => nil,
    }
    command_line = [
      RbConfig.ruby, "-v", "-S", "benchmark-driver", File.expand_path(benchmark)
    ]

    desc "Run #{name} benchmark"
    task name do
      puts("```")
      sh(env, *command_line)
      puts("```")
    end
    benchmark_tasks << "benchmark:#{name}"
  end
end

desc "Run all benchmarks"
task benchmark: benchmark_tasks

task :sync_tool do
  require 'fileutils'
  FileUtils.cp "../ruby/tool/lib/test/unit/core_assertions.rb", "./test/lib"
  FileUtils.cp "../ruby/tool/lib/envutil.rb", "./test/lib"
  FileUtils.cp "../ruby/tool/lib/find_executable.rb", "./test/lib"
end
