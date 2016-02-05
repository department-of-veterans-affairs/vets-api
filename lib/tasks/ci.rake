desc "Runs the continuous integration scripts"
task ci: [:lint, :security, :spec]

task default: :ci
