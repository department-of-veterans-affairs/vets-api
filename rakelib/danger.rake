# frozen_string_literal: true

require 'open3'
require './rakelib/support/shell_command'
require 'pp'

# see: https://danger.systems/ruby/
desc 'run danger-ruby'
task :danger do
  require 'rainbow'

  puts 'running danger...'
  puts "External encoding = #{Encoding.default_external}"

  danger_result = ShellCommand.run('LANG=en_US.UTF-8 danger --verbose')

  puts "\n\n"

  if danger_result
    puts Rainbow('Danger ran successfully.').green
  else
    puts Rainbow('Failed. Something went wrong while running danger-ruby').red
    exit!(1)
  end
end
