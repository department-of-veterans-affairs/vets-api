# frozen_string_literal: true

require 'open3'
require './rakelib/support/shell_command'

desc 'shortcut to run all linting tools, at the same time.'
task :lint, [:files] => [:environment] do |_, args|
  require 'rainbow'

  # comes in as 'Jenkinsfile|app/controllers/v0/addresses_controller.rb|config/routes.rb'
  # but we want 'app/controllers/v0/addresses_controller.rb config/routes.rb'
  filess = args[:files].split('|').select{ |filename| filename.include?('.rb') || filename.include?('.rake') }.join(' ')

  opts = '-r rubocop-thread_safety '

  opts += if ENV['CI']
            "-r rubocop/formatter/junit_formatter.rb \
            --format RuboCop::Formatter::JUnitFormatter --out log/rubocop.xml \
            --format clang \
            --parallel"
          else
            '--display-cop-names --auto-correct'
          end

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
