# frozen_string_literal: true

require 'pp'

namespace :form526 do
  desc 'Get all jobs within a date period. [<start date>,<end date>]'
  task :jobs, %i[start_date end_date] => [:environment] do |_, args|
    def print_row(created_at, updated_at, job_id, status)
      printf "%-24s %-24s %-25s %s\n", created_at, updated_at, job_id, status
    end

    TRXS = AsyncTransaction::EVSS::VA526ezSubmitTransaction

    start_date = args[:start_date] || 30.days.ago.utc.to_s
    end_date = args[:end_date] || Time.zone.now.utc.to_s

    print_row('created at:', 'updated at:', 'job id:', 'job status:')
    TRXS.where('created_at BETWEEN ? AND ?', start_date, end_date)
        .order(created_at: :desc)
        .find_each do |job|
      print_row(job.created_at, job.updated_at, job.transaction_id, job.transaction_status)
    end
  end

  desc 'Get job details given a job id'
  task :job, %i[job_id] => [:environment] do |_, args|
    raise 'No job id provided' unless args[:job_id]

    job = AsyncTransaction::EVSS::VA526ezSubmitTransaction.where(transaction_id: args[:job_id]).first

    form = JSON.parse(job.saved_claim.form)
    form['veteran'] = 'OMITTED'

    puts '----------------------------------------'
    puts 'Job Details:'
    puts "user uuid: #{job.user_uuid}"
    puts "source id: #{job.source_id}"
    puts "source: #{job.source}"
    puts "transaction status: #{job.transaction_status}"
    puts "created at: #{job.created_at}"
    puts "updated at: #{job.updated_at}"
    puts '----------------------------------------'
    puts 'Job Metadata:'
    puts job.metadata
    puts '----------------------------------------'
    puts 'Form Data:'
    puts JSON.pretty_generate(form)
  end

  desc 'dry run for migrating existing 526 submissions to the new tables'
  task migrate_dry_run: :environment do
    migrated = 0

    DisabilityCompensationSubmission.find_each do |submission|
      user_uuid = submission.async_transaction.user_uuid
      job_statuses = submission.job_statuses
      claim_id = nil
      if submission.async_transaction.transaction_status == 'received'
        claim_id = JSON.parse(submission.async_transaction.metadata)['claim_id']
      end

      submission_hash = {
        user_uuid: user_uuid,
        saved_claim_id: submission.disability_compensation_claim.id,
        submitted_claim_id: claim_id,
        auth_headers_json: { metadata: 'migrated data auth headers unavailable' }.to_json,
        form_json: { metadata: 'migrated data form unavailable' }.to_json,
        workflow_complete: job_statuses.all? { |js| js.status == 'success' },
        created_at: submission.created_at,
        updated_at: submission.updated_at
      }

      puts "\n\n---"
      puts 'Form526Submission:'
      pp submission_hash

      job_statuses.each do |js|
        status_hash = {
          form526_submission_id: nil,
          job_id: js.job_id,
          job_class: js.job_class,
          status: js.status,
          error_class: nil,
          error_message: js.error_message,
          updated_at: js.updated_at
        }

        puts 'Form526JobStatus'
        pp status_hash
      end

      migrated += 1
      puts "---\n\n"
      puts "Submissions migrated: #{migrated}"
    end
  end

  desc 'migrate existing 526 submissions to the new tables'
  task migrate_data: :environment do
    migrated = 0

    DisabilityCompensationSubmission.find_each do |submission|
      user_uuid = submission.async_transaction.user_uuid
      job_statuses = submission.job_statuses
      claim_id = nil
      if submission.async_transaction.transaction_status == 'received'
        claim_id = JSON.parse(submission.async_transaction.metadata)['claim_id']
      end

      new_submission = Form526Submission.create(
        user_uuid: user_uuid,
        saved_claim_id: submission.disability_compensation_claim.id,
        submitted_claim_id: claim_id,
        auth_headers_json: { metadata: 'migrated data auth headers unavailable' }.to_json,
        form_json: { metadata: 'migrated data form unavailable' }.to_json,
        workflow_complete: job_statuses.all? { |js| js.status == 'success' },
        created_at: submission.created_at,
        updated_at: submission.updated_at
      )

      job_statuses.each do |js|
        Form526JobStatus.create(
          form526_submission_id: new_submission.id,
          job_id: js.job_id,
          job_class: js.job_class,
          status: js.status,
          error_class: nil,
          error_message: js.error_message,
          updated_at: js.updated_at
        )
      end

      migrated += 1
    end

    puts "Submissions migrated: #{migrated}"
  end
end
