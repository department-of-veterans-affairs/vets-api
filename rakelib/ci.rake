# frozen_string_literal: true

desc 'Runs the continuous integration scripts'
task ci: [:security, :spec]

task default: :ci
