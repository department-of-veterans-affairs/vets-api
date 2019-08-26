# frozen_string_literal: true

desc 'Runs the continuous integration scripts'
task ci: %i[spec:with_codeclimate_coverage]

task default: :ci

desc "run rspec tests and report results to CodeClimate"
namespace :spec do
  task with_codeclimate_coverage: :environment do
    system('./cc-test-reporter before-build') if ENV['CI']
    begin
      Rake::Task['spec'].invoke
    rescue SystemExit => e
      exit_status = e.status
    else
      system('./cc-test-reporter after-build -t simplecov echo') if ENV['CI']
      exit_status = 0
    end
    exit exit_status
  end
end
