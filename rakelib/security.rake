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
  # TODO: remove --ignore CVE-2019-5420 after updating to rails 5.2
  audit_result = ShellCommand.run('bundle-audit check --ignore CVE-2019-5420')

  puts "\n"
  if brakeman_result && audit_result
    puts Rainbow('Passed. No obvious security vulnerabilities.').green
  else
    puts Rainbow('Failed. Security vulnerabilities were found.').red
    exit!(1)
  end
end
