# frozen_string_literal: true

desc 'run yardoc against changed files, or supplied file list'
task yardoc: :environment do
  require 'rainbow'

  # dynamically create dummy tasks to prevent rake error
  ARGV.each { |a| task(a.to_sym {}) }

  head_sha = `git rev-parse --abbrev-ref HEAD`.chomp.freeze
  base_sha = 'origin/master'

  # get the glob list
  globs = ARGV[1..]
  globs = ['*.rb', '*.rake'] if globs.empty?

  # git diff the glob list - only want to check the changed files
  globs = globs.map { |g| "'#{g}'" }.join(' ')
  cmd = "git diff #{base_sha}...#{head_sha} --name-only -- #{globs}"
  puts "\n#{cmd}\n"

  # filter to only ruby files
  # lots of false positives if yardoc is run on other files
  files = `#{cmd}`.split("\n").select { |f| %w[.rb .rake].include?(File.extname(f)) }
  if files.empty?
    puts Rainbow('Finished. No RUBY files changed.').yellow
    exit!
  end

  puts 'running yardoc ...'
  puts yardoc_output = `yardoc #{files.join(' ')}`.strip.split("\n")
  puts "\n"

  # non zero exit == parsing error
  if (yardoc_result = $?.exitstatus) > 0
    puts Rainbow('Failed. Documentation issues were found.').red
    exit!(yardoc_result)
  end

  percentage = yardoc_output.last.strip[/\d+\.\d+/].to_f
  if percentage < 100
    puts Rainbow('Warning. Documentation is missing.').yellow
    exit!
  end

  puts Rainbow('Passed. Everything looks documented!').green
end
