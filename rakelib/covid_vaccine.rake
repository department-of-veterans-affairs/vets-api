# frozen_string_literal: true

namespace :covid_vaccine do
  desc 'Display summary of submissions by state'
  task state_summary: :environment do |_task|
    states = CovidVaccine::V0::ExpandedRegistrationSubmission.group('state').count
    states.each do |k, v|
      puts "#{k || 'nil'}: #{v}"
    end
  end

  desc 'Generate enrollment batch file for specified existing batch id. Does not update state'
  task :write_batch_file, %i[batch_id] => [:environment] do |_, args|
    raise 'No batch_id provided' unless args[:batch_id]

    batch_id = args[:batch_id]
    filename = "DHS_load_MANUAL_#{batch_id}_SLA_unknown_records.txt"
    File.open(filename, 'w') do |file|
      record_count = CovidVaccine::V0::EnrollmentProcessor.write_to_file(batch_id, file)
      puts "Generated batch file #{filename} for batch id #{batch_id} with #{record_count} records"
      puts 'NOTE: state for records was not updated as a result of this operation'
    end
  end

  desc 'Update state of records in batch to pending'
  task :set_pending_state, [:batch_id] => [:environment] do |_, args|
    raise 'No batch_id provided' unless args[:batch_id]

    batch_id = args[:batch_id]
    CovidVaccine::V0::EnrollmentProcessor.update_state_to_pending(batch_id)
    puts "Updated state to enrollment_pending for batch id #{batch_id}"
  end

  desc 'Perform enrollment SFTP upload for max (count) records'
  task :perform_enrollment_upload, [:count] => [:environment] do |_, _args|
    batch_id = CovidVaccine::V0::EnrollmentProcessor.batch_records!
    processor = CovidVaccine::V0::EnrollmentProcessor.new(batch_id)
    processor.process_and_upload!
    puts "Uploaded batch file for batch id #{batch_id} successfully"
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

  desc 'Write mapped facility IDs to record for a specified batch'
  task :map_facility_ids_for_batch, [:batch_id] => [:environment] do |_, args|
    raise 'No batch_id provided' unless args[:batch_id]

    batch_id = args[:batch_id]
    count = 0
    CovidVaccine::V0::ExpandedRegistrationSubmission.where(batch_id:).find_each do |submission|
      resolver = CovidVaccine::V0::FacilityResolver.new
      mapped_facility = resolver.resolve(submission)
      submission.eligibility_info = { preferred_facility: mapped_facility }
      submission.save!
      count += 1
    end
    puts "Updated mapped facility info for #{count} records in batch #{batch_id}"
  end

  desc 'Reprocess records with state = enrollment_complete that have not been sent to vetext'
  task reprocess_completed_records: [:environment] do |_task|
    count = 0
    CovidVaccine::V0::ExpandedRegistrationSubmission.where(state: 'enrollment_complete').find_each do |submission|
      CovidVaccine::ExpandedSubmissionJob.perform_async(submission.id)
      count += 1
    end
    puts "Processed #{count} records with state=enrollment_complete"
  end
end
