# frozen_string_literal: true

require 'open3'
require './rakelib/support/shell_command'

desc 'run yardoc against changed files, or supplied file list'
task :yardoc, [:files] => [:environment] do |_, args|
  require 'rainbow'

  files = args[:files]

  puts 'running yardoc ...'
  yardoc_result = ShellCommand.run("yardoc #{files}")

  puts "\n"
  if yardoc_result
    puts Rainbow('Passed. Everything looks stylish!').green
  else
    puts Rainbow('Failed. Documentation issues were found.').red
    exit!(1)
  end
end
