# frozen_string_literal: true

require "bundler/setup"

require "bundler/gem_tasks"

task :clean do
  FileUtils.rm_f(Dir.glob("test/dummy/log/*.log"), verbose: true)
end

desc "Regenerate tables of contents in some files"
task "toc" do
  require "mkmf"
  if find_executable0("markdown-toc")
    sh "markdown-toc --maxdepth=3 -i GUIDE.md"
  else
    puts "WARN: cannot find markdown-toc, skipping. install with 'npm install markdown-toc'"
  end
end
