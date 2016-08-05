require "open3"
require "rainbow"

desc "shortcut to run all linting tools, at the same time."
task :lint do
  opts = ENV["CI"] ? "" : "--auto-correct"
  puts "running rubocop..."
  rubocop_result = ShellCommand.run("rubocop #{opts} --color")

  puts "\n"
  if rubocop_result && jshint_result
    puts Rainbow("Passed. Everything looks stylish!").green
  else
    puts Rainbow("Failed. Linting issues were found.").red
    exit!(1)
  end
end
