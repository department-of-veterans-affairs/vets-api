# frozen_string_literal: true

require 'open3'
require './rakelib/support/shell_command'

desc 'shortcut to run all linting tools, at the same time.'
task :security do
  require 'rainbow'

  puts 'running Brakeman security scan...'
  brakeman_result = ShellCommand.run(
    'brakeman --exit-on-warn --run-all-checks --confidence-level=2 --format=plain'
  )

  puts 'running bundle-audit to check for insecure dependencies...'
  exit!(1) unless ShellCommand.run('bundle-audit update')
  audit_result = ShellCommand.run('bundle-audit check')
  puts "\n"

  puts 'running bundle-audit on sub-modules...'
  starting_dir = Dir.pwd
  sub_module_results = []
  Dir.glob('modules/*').select do |module_f|
    next unless File.directory? module_f
    next unless File.exist?(module_f + '/Gemfile.lock')

    puts "module [#{module_f}]..."
    begin
      Dir.chdir(module_f)
      sub_module_results.push(ShellCommand.run('bundle-audit check'))
    ensure
      Dir.chdir(starting_dir)
    end
  end

  puts "\n"

  if brakeman_result && audit_result && !sub_module_results.include?(false)
    puts Rainbow('Passed. No obvious security vulnerabilities.').green
  else
    puts Rainbow('Failed. Security vulnerabilities were found.').red
    exit!(1)
  end
end
