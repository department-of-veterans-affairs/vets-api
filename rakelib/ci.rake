# frozen_string_literal: true

desc 'Runs the continuous integration scripts'
task ci: %i[spec:with_codeclimate_coverage]

task default: :ci

desc 'run rspec tests and report results to CodeClimate'
namespace :spec do
  task with_codeclimate_coverage: :environment do
    puts Dir["/cc*"]
    if ENV['CC_TEST_REPORTER_ID']
      puts 'notifying CodeClimate of test run'
      puts "cc error" unless system('/cc-test-reporter before-build')
    end
    exit_status = begin
                    Rake::Task['spec'].invoke
                  rescue SystemExit => e
                    e.status
                  else
                    0
                  end

    if ENV['CC_TEST_REPORTER_ID']
      puts 'reporting coverage to CodeClimate'
      puts "cc error" unless system('/cc-test-reporter after-build -t simplecov')
    end
    exit exit_status
  end
end
