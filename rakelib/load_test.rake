# frozen_string_literal: true

namespace :load_test do
  # usage: bundle exec rake 'load_test:hca_ee[1235]'
  desc 'Load test the HCA Enrollment & Eligibility API'
  task :hca_ee, [:icn] => [:environment] do |_, args|
    require './rakelib/support/vic_load_test'
    require 'hca/enrollment_eligibility/service'

    LoadTest.measure_elapsed do
      10.times do
        HCA::EnrollmentEligibility::Service.new.lookup_user(args.icn)
      end
    end
  end
end
