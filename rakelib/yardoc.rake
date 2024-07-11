# frozen_string_literal: true

require 'open3'
require './rakelib/support/shell_command'

desc 'run yardoc against changed files, or supplied file list'
task :yardoc do
  require 'rainbow'

  # dynamically create dummy tasks to prevent rake error
  ARGV.each { |a| task a.to_sym do ; end }

  HEAD_SHA = `git rev-parse --abbrev-ref HEAD`.chomp.freeze
  BASE_SHA = 'origin/master'

  # get the glob list
  globs = ARGV[1..]
  globs = ["*.rb"] if globs.empty?

  # git diff the glob list - only want to check the changed files
  globs = globs.map { |g| "'#{g}'" }.join(" ")
  cmd = "git diff #{BASE_SHA}...#{HEAD_SHA} --name-only -- #{globs}"
  puts "\n#{cmd}"

  # filter to only ruby files (lots of issues if yardoc is run on other files)
  files = `#{cmd}`.split("\n").select { |f| File.extname(f) == '.rb' }
  if files.empty?
    puts Rainbow('Finished. No `*.rb` files changed.').yellow
    exit!
  end

  puts 'running yardoc ...'
  yardoc_result = ShellCommand.run("yardoc #{files.join(" ")}")

  puts "\n"
  if yardoc_result
    puts Rainbow('Passed. Everything looks stylish!').green
  else
    puts Rainbow('Failed. Documentation issues were found.').red
    exit!(1)
  end
end
