# frozen_string_literal: true

require './rakelib/support/sessions_arg_serializer.rb'
require './rakelib/support/sessions_file_serializer.rb'

namespace :load_test do
  desc 'Create test sessions and output result with a merged curl/locust compatible header'
  task :sessions, %i[count mhv_id] => [:environment] do |_, args|
    puts SessionsArgSerializer.new(args).generate_cookies_sessions
  end

  desc 'Create test sessions from json file and output result with a merged curl/locust compatible header'
  task :sessions_from_file, [:sessions_json_file] => [:environment] do |_, args|
    raise 'No sessions JSON file provided' unless args[:sessions_json_file]

    puts SessionsFileSerializer.new(args[:sessions_json_file]).generate_cookies_sessions
  end

  # usage: bundle exec rake 'load_test:hca_ee[1235]'
  desc 'Load test the HCA Enrollment & Eligibility API'
  task :hca_ee, [:icn] => [:environment] do |_, args|
    require './rakelib/support/vic_load_test'

    LoadTest.measure_elapsed do
      10.times do
        HCA::EnrollmentEligibility::Service.new.lookup_user(args.icn)
      end
    end
  end
end
