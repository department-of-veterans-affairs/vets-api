# frozen_string_literal: true

desc 'run yardoc against changed files'
task yardoc: :environment do
  require 'rainbow'
  require 'yaml'

  head_sha = `git rev-parse --abbrev-ref HEAD`.chomp.freeze
  base_sha = 'origin/master'

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

  yardoc_yaml = Rails.root.join('.github', 'workflows', 'yardoc.yml')
  config = YAML.load_file(yardoc_yaml)

  # true == 'on' in GH yaml
  paths = config[true]['pull_request']['paths'].select do |path|
    files.find { |file| File.fnmatch(path, file) }
  end

  puts 'running yardoc ...'
  puts "\n"
  puts yardoc_output = `yardoc #{paths.join(' ')}`.strip.split("\n")
  puts "\n"

  # non zero exit == parsing error
  if (yardoc_result = $CHILD_STATUS.exitstatus).positive?
    puts Rainbow('Failed. Documentation issues were found.').red
    exit!(yardoc_result)
  end

  # 'fail' if not 100% - mark this task as required in github to block merging
  percentage = yardoc_output.last.strip[/\d+\.\d+/].to_f
  if percentage < 100
    puts `yard stats --list-undoc #{paths.join(' ')}`
    puts Rainbow('Warning. Documentation is missing.').yellow
    exit!(1)
  end

  puts Rainbow('Passed. Everything looks documented!').green
end
