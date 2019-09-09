# frozen_string_literal: true

desc 'Runs the continuous integration scripts'

task ci: %i[lint security parallel:spec_with_codeclimate_coverage]

task default: :ci

desc 'run rspec tests and report results to CodeClimate'
namespace :parallel do
  task spec_with_codeclimate_coverage: :environment do
    if ENV['CC_TEST_REPORTER_ID']
      puts 'notifying CodeClimate of test run'
      system('/cc-test-reporter before-build')
    end
    exit_status = begin
                    Rake::Task['parallel:spec']
                      .invoke(nil, nil, nil, 'modules/*/spec/**/*_spec.rb')
                  rescue SystemExit => e
                    e.status
                  else
                    0
                  end

    if ENV['CC_TEST_REPORTER_ID']
      puts 'reporting coverage to CodeClimate'
      system('/cc-test-reporter after-build -t simplecov')
    end
    exit exit_status
  end
end
