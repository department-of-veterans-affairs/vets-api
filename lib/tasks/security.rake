require "open3"
require "rainbow"

desc "shortcut to run all linting tools, at the same time."
task :security do
  puts "running Brakeman security scan..."
  brakeman_result = ShellCommand.run(
    "brakeman --exit-on-warn --run-all-checks --confidence-level=2"
  )

  puts "running bundle-audit to check for insecure dependencies..."
  exit!(1) unless ShellCommand.run("bundle-audit update")
  audit_result = ShellCommand.run("bundle-audit check")

  puts "\n"
  if brakeman_result && audit_result
    puts Rainbow("Passed. No obvious security vulnerabilities.").green
  else
    puts Rainbow("Failed. Security vulnerabilities were found.").red
    exit!(1)
  end
end
