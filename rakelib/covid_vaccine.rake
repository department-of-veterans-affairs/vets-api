# frozen_string_literal: true

namespace :covid_vaccine do
  desc 'Display summary of submissions by state'
  task state_summary: :environment do |_task|
    states = CovidVaccine::V0::ExpandedRegistrationSubmission.group('state').count
    states.each do |k, v|
      puts "#{k || 'nil'}: #{v}"
    end
  end

  # desc 'Generate enrollment batch file for max (count) records. Record batch id but do not update state'
  # task :write_enrollment_file, [:count] => [:environment] do |_, args|
  #   count = args[:count]
  #   processor = CovidVaccine::V0::EnrollmentProcessor.new
  #   filename = processor.write_to_file(count)
  #   puts "Generated batch file #{filename} for batch id #{processor.batch_id}"
  #   puts 'Use task covid_vaccine:set_pending_state to update state after manual upload'
  # end

  # desc 'Update state of records in batch to pending'
  # task :set_pending_state, [:batch_id] => [:environment] do |_, args|
  #   batch_id = args[:batch_id]
  #   CovidVaccine::V0::EnrollmentProcessor.set_pending_state(batch_id)
  #   puts "Updated state to enrollment_pending for batch id #{batch_id}"
  # end

  desc 'Perform enrollment SFTP upload for max (count) records'
  task :perform_enrollment_upload, [:count] => [:environment] do |_, args|
    count = args[:count]
    processor = CovidVaccine::V0::EnrollmentProcessor.new
    processor.process_and_upload
    puts "Uploaded batch file for batch id #{processor.batch_id} successfully"
  end

  desc 'Write mapped facility IDs to record. Short-lived task to handle input anomaly'
  task map_facility_ids: [:environment] do |_task|
    count = 0
    CovidVaccine::V0::ExpandedRegistrationSubmission.where(state: 'received').find_each do |submission|
      resolver = CovidVaccine::V0::FacilityResolver.new
      mapped_facility = resolver.resolve(submission)
      submission.eligibility_info = { preferred_facility: mapped_facility }
      submission.save!
      count += 1
    end
    CovidVaccine::V0::ExpandedRegistrationSubmission.where(state: nil).find_each do |submission|
      resolver = CovidVaccine::V0::FacilityResolver.new
      mapped_facility = resolver.resolve(submission)
      submission.eligibility_info = { preferred_facility: mapped_facility }
      submission.save!
      count += 1
    end
    puts "Updated mapped facility info for #{count} records"
  end
end
