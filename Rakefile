# frozen_string_literal: true

require "bundler/setup"

require "bundler/gem_tasks"

task :clean do
  FileUtils.rm_f(Dir.glob("test/dummy/log/*.log"), verbose: true)
end
