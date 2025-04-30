# frozen_string_literal: true

desc 'run yardoc against changed files'
task yardoc: :environment do
  require 'rainbow'
  require 'yaml'

  head_sha = `git rev-parse --abbrev-ref HEAD`.chomp.freeze
  base_sha = "origin/#{GITHUB_BASE_REF}"

  # git diff the glob list - only want to check the changed files
  globs = ['*.rb']
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

  # only run on paths specified in GH action yaml
  yardoc_yaml = Rails.root.join('.github', 'workflows', 'yardoc.yml')
  config = YAML.load_file(yardoc_yaml)

  # true == 'on' in GH action yaml
  paths = config[true]['pull_request']['paths'].select do |path|
    files.find { |file| File.fnmatch(path, file) }
  end
  if paths.empty?
    puts Rainbow('Finished. No watched paths changed.').yellow
    exit!
  end

  paths = paths.map { |g| "'#{g}'" }.join(' ')

  cmd = "yardoc #{paths}"
  puts "#{cmd}\n\n"
  yardoc_output = `#{cmd}`.strip.split("\n")

  # non zero exit == parsing error
  if (yardoc_result = $CHILD_STATUS.exitstatus).positive?
    puts yardoc_output
    puts "\n"
    puts Rainbow('Failed. Documentation issues were found.').red

    exit(yardoc_result)
  end

  # 'fail' if not 100% - mark this task as required in github to block merging
  percentage = yardoc_output.last.strip[/\d+\.\d+/].to_f
  if percentage < 100.0
    cmd = "yard stats --list-undoc #{paths}"
    puts "#{cmd}\n\n"

    yardoc_stats = `#{cmd}`.strip.split("\n")
    puts yardoc_stats
    puts "\n"
    puts Rainbow('Warning. Documentation is missing.').yellow

    exit(1)
  end

  puts yardoc_output
  puts "\n"
  puts Rainbow('Passed. Everything looks documented!').green
end
