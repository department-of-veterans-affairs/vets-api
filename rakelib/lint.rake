# frozen_string_literal: true

require 'open3'
require './rakelib/support/shell_command'

desc 'shortcut to run all linting tools, at the same time.'
task :lint do
  require 'rainbow'

  opts = if ENV['CI']
           "-r $(bundle show rubocop-junit-formatter)/lib/rubocop/formatter/junit_formatter.rb \
           --format RuboCop::Formatter::JUnitFormatter --out log/rubocop.xml \
           --format clang"
         else
           '--display-cop-names --auto-correct'
         end

  puts 'running rubocop...'
  rubocop_result = ShellCommand.run("rubocop #{opts} --color")

  puts "\n"
  if rubocop_result
    puts Rainbow('Passed. Everything looks stylish!').green
  else
    puts Rainbow('Failed. Linting issues were found.').red
    exit!(1)
  end
end
