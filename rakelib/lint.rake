# frozen_string_literal: true

require 'open3'
require './rakelib/support/shell_command'

desc 'shortcut to run all linting tools, at the same time.'
task :lint, [:files] => [:environment] do |_, args|
  require 'rainbow'

  files = args[:files]

  opts = if ENV['CI']
           "-r rubocop/formatter/junit_formatter.rb \
            --format RuboCop::Formatter::JUnitFormatter --out log/rubocop.xml \
            --format clang \
            --parallel"
         else
           '--display-cop-names --autocorrect'
         end

  opts += ' --force-exclusion' if files.present?

  puts 'running rubocop...'
  rubocop_result = ShellCommand.run("rubocop #{opts} --color #{files}")

  puts "\n"
  if rubocop_result
    puts Rainbow('Passed. Everything looks stylish!').green
  else
    puts Rainbow('Failed. Linting issues were found.').red
    exit!(1)
  end
end
