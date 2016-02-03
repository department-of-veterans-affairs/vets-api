require 'open3'
require 'rainbow'

class ShellCommand
  # runs shell command and prints output
  # returns boolean depending on the success of the command
  def self.run(command)
    success = false

    Open3.popen2e(command) do |stdin, stdout_and_stderr, thread|
      while line = stdout_and_stderr.gets do 
        puts(line) 
      end

      success = thread.value == 0
    end
    
    success
  end
end

desc "Shortcut to run all linting tools, at the same time."
task :lint do
  puts "Running scss-lint..."
  scss_result = ShellCommand.run("scss-lint --color")

  opts = ENV['CI'] ? "" : "--auto-correct"
  puts "Running rubocop..."
  rubocop_result = ShellCommand.run("rubocop #{opts} --color")

  puts "\nRunning jshint..."
  jshint_result = ShellCommand.run("rake jshint")


  puts "\n"
  if scss_result && rubocop_result && jshint_result
    puts Rainbow("Passed. Everything looks stylish!").green
  else
    puts Rainbow("Failed. Linting issues were found.").red
  end
end