# frozen_string_literal: true

desc 'Runs the continuous integration scripts'

task ci: %i[lint security danger parallel:spec_with_codeclimate_coverage]

task default: :ci

desc 'run rspec tests and report results to CodeClimate'
namespace :parallel do
  task spec_with_codeclimate_coverage: :environment do
    if ENV['CC_TEST_REPORTER_ID']
      puts 'notifying CodeClimate of test run'
      system('/cc-test-reporter before-build')
    end

    # parallel_tests wasn't handling the file regex properly so we're listing every test file
    test_files = Dir.glob(['spec/**/*_spec.rb', 'modules/*/spec/**/*_spec.rb']).join(' ')
    exit_status = begin
                    Rake::Task['parallel:spec']
                      .invoke(nil, nil, nil, test_files)
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

$stdout.sync = false
