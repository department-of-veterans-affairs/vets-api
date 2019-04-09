# frozen_string_literal: true

require 'pp'

namespace :form526 do
  desc 'Get all submissions within a date period. [<start date: yyyy-mm-dd>,<end date: yyyy-mm-dd>]'
  task :submissions, %i[start_date end_date] => [:environment] do |_, args|
    def print_row(created_at, updated_at, id, claim_id, complete, version) # rubocop:disable Metrics/ParameterLists
      printf "%-24s %-24s %-15s %-10s %-10s %s\n", created_at, updated_at, id, claim_id, complete, version
    end

    def print_total(header, total)
      printf "%-20s %s\n", header, total
    end

    def print_errors(errors)
      errors.each do |k, v|
        puts "< Submission id: #{k} >"
        puts '*****************'
        results = v.map do |e|
          msgs = e['messages'].map { |m| "Message:  #{m}" }
          <<~ERRORS
            Class:    #{e['class']}
            Status:   #{e['status']}
            Error:    #{e['error']}
            #{msgs.join("\n")}
          ERRORS
        end
        puts results.join("\n")
        puts '*****************'
        puts ''
      end
    end
    start_date = args[:start_date]&.to_date || 30.days.ago.utc
    end_date = args[:end_date]&.to_date || Time.zone.now.utc

    puts '------------------------------------------------------------'
    print_row('created at:', 'updated at:', 'submission id:', 'claim id:', 'workflow complete:', 'form version:')

    submissions = Form526Submission.where(
      'created_at BETWEEN ? AND ?', start_date.beginning_of_day, end_date.end_of_day
    )

    outage_errors = 0
    other_errors = 0
    errors = {}

    # Scoped order are ignored for find_each. Its forced to be batch order (on primary key)
    # This should be fine as created_at dates correlate directly to PKs
    submissions.find_each do |s|
      version = 'version 1: IO'
      s.form526_job_statuses.each do |j|
        version = 'version 2: AC' if j.job_class == 'SubmitForm526AllClaim'
        if (j.job_class == 'SubmitForm526IncreaseOnly' || j.job_class == 'SubmitForm526AllClaim') &&
           j.error_message.present?
          j.error_message.include?('submit.establishClaim.serviceError') ? (outage_errors += 1) : (other_errors += 1)
        end

        # Store all Errors for error reporting
        if j.error_class.present?
          errors[s.id] = [] if errors[s.id].blank?
          error = {
            'class' => j.job_class.to_s,
            'status' => j.status,
            'error' => j.error_class,
            'messages' => []
          }

          # This regex will parse out the errors returned from EVSS.
          # The error message will be in an ugly stringified hash. There can be multiple
          # errors in a message. Each error will have a `key` and a `text` key. The
          # following regex will group all key/text pairs together that are present in
          # the string.
          msgs_regex = /key\\"=>\\"(.*?)\\".*?text\\"=>\\"(.*?)\\"/
          # Check if its an EVSS error and parse, otherwise store the entire message
          messages = if j.error_message.include?('=>') && j.error_class != 'Common::Exceptions::BackendServiceException'
                       j.error_message.scan(msgs_regex)
                     else
                       [[j.error_message]]
                     end
          messages.each do |m|
            message = m[1].present? ? "#{m[0]}: #{m[1]}" : m[0]
            error['messages'].append(message)
          end

          errors[s.id].append(error)
        end
      end
      print_row(s.created_at, s.updated_at, s.id, s.submitted_claim_id, s.workflow_complete, version)
    end

    total_jobs = submissions.count
    success_jobs = submissions.group(:workflow_complete).count[true] || 0
    fail_jobs = total_jobs - success_jobs

    puts '------------------------------------------------------------'
    puts "* Job Success/Failure counts between #{start_date} - #{end_date} *"
    print_total('Total Jobs: ', total_jobs)
    print_total('Successful Jobs: ', success_jobs)
    print_total('Failed Jobs: ', fail_jobs)
    puts '------------------------------------------------------------'
    puts '* Failure Counts for form526 Submission Job (not including uploads/cleanup/etc...) *'
    print_total('Outage Failures: ', outage_errors)
    print_total('Other Failures: ', other_errors)
    puts '------------------------------------------------------------'
    puts '* Error Report *'
    puts ''
    print_errors(errors)
  end

  desc 'Get one or more submission details given an array of ids'
  task submission: :environment do |_, args|
    raise 'No submission ids provided' unless args.extras.count.positive?

    Rails.application.eager_load!

    args.extras.each do |id|
      submission = Form526Submission.find(id)

      saved_claim_form = JSON.parse(submission.saved_claim.form)
      saved_claim_form['veteran'] = 'FILTERED'

      auth_headers = JSON.parse(submission.auth_headers_json)
      # There have been prod instances of users not having a ssn
      ssn = auth_headers['va_eauth_pnid'] || ''

      puts '------------------------------------------------------------'
      puts "Submission (#{submission.id}):\n\n"
      puts "user uuid: #{submission.user_uuid}"
      puts "user edipi: #{auth_headers['va_eauth_dodedipnid']}"
      puts "user participant id: #{auth_headers['va_eauth_pid']}"
      puts "user ssn: #{ssn.gsub(/(?=\d{5})\d/, '*')}"
      puts "saved claim id: #{submission.saved_claim_id}"
      puts "submitted claim id: #{submission.submitted_claim_id}"
      puts "workflow complete: #{submission.workflow_complete}"
      puts "created at: #{submission.created_at}"
      puts "updated at: #{submission.updated_at}"
      puts "\n"
      puts '----------------------------------------'
      puts "Jobs:\n\n"
      submission.form526_job_statuses.each do |s|
        puts s.job_class.to_s
        puts "  status: #{s.status}"
        puts "  error: #{s.error_class}" if s.error_class
        puts "    message: #{s.error_message}" if s.error_message
        puts "  updated at: #{s.updated_at}"
        puts "\n"
      end
      puts '----------------------------------------'
      puts "Form JSON:\n\n"
      puts JSON.pretty_generate(saved_claim_form)
      puts "\n\n"
    end
  end

  def create_submission_hash(claim_id, submission, user_uuid)
    {
      user_uuid: user_uuid,
      saved_claim_id: submission.disability_compensation_id,
      submitted_claim_id: claim_id,
      auth_headers_json: { metadata: 'migrated data auth headers unavailable' }.to_json,
      form_json: { metadata: 'migrated data form unavailable' }.to_json,
      workflow_complete: submission.job_statuses.all? { |js| js.status == 'success' },
      created_at: submission.created_at,
      updated_at: submission.updated_at
    }
  end

  def create_status_hash(submission_id, job_status)
    {
      form526_submission_id: submission_id,
      job_id: job_status.job_id,
      job_class: job_status.job_class,
      status: job_status.status,
      error_class: nil,
      error_message: job_status.error_message,
      updated_at: job_status.updated_at
    }
  end

  desc 'update all disability compensation claims to have the correct type'
  task update_types: :environment do
    # `update_all` is being used because the `type` field will reset to `SavedClaim::DisabilityCompensation`
    # if a `claim.save` is done
    # rubocop:disable Rails/SkipsModelValidations
    SavedClaim::DisabilityCompensation.where(type: 'SavedClaim::DisabilityCompensation')
                                      .update_all(type: 'SavedClaim::DisabilityCompensation::Form526IncreaseOnly')
    # rubocop:enable Rails/SkipsModelValidations
  end

  desc 'dry run for migrating existing 526 submissions to the new tables'
  task migrate_dry_run: :environment do
    migrated = 0

    DisabilityCompensationSubmission.find_each do |submission|
      job = AsyncTransaction::EVSS::VA526ezSubmitTransaction.find(submission.va526ez_submit_transaction_id)
      user_uuid = job.user_uuid
      claim_id = nil
      claim_id = JSON.parse(job.metadata)['claim_id'] if job.transaction_status == 'received'

      submission_hash = create_submission_hash(claim_id, submission, user_uuid)

      puts "\n\n---"
      puts 'Form526Submission:'
      pp submission_hash

      submission.job_statuses.each do |job_status|
        status_hash = create_status_hash(nil, job_status)
        puts 'Form526JobStatus:'
        pp status_hash
      end

      migrated += 1
      puts "---\n\n"
    end

    puts "Submissions migrated: #{migrated}"
  end

  desc 'migrate existing 526 submissions to the new tables'
  task migrate_data: :environment do
    migrated = 0

    DisabilityCompensationSubmission.find_each do |submission|
      job = AsyncTransaction::EVSS::VA526ezSubmitTransaction.find(submission.va526ez_submit_transaction_id)
      user_uuid = job.user_uuid
      claim_id = nil
      claim_id = JSON.parse(job.metadata)['claim_id'] if job.transaction_status == 'received'

      new_submission = Form526Submission.create(create_submission_hash(claim_id, submission, user_uuid))

      submission.job_statuses.each do |job_status|
        Form526JobStatus.create(create_status_hash(new_submission.id, job_status))
      end

      migrated += 1
    end

    puts "Submissions migrated: #{migrated}"
  end
end
