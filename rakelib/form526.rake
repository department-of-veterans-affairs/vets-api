# frozen_string_literal: true

require 'pp'
require 'set'

namespace :form526 do
  desc 'Get all submissions within a date period. [<start date: yyyy-mm-dd>,<end date: yyyy-mm-dd>]'
  task :submissions, %i[start_date end_date] => [:environment] do |_, args|
    # rubocop:disable Style/FormatStringToken
    # This forces string token formatting. Our examples don't match
    # what this style is enforcing
    # rubocop: format('%<greeting>s', greeting: 'Hello')
    # vets-api example: printf "%-20s %s\n", header, total

    def print_row(created_at, updated_at, id, c_id, p_id, complete, version) # rubocop:disable Metrics/ParameterLists
      printf "%-24s %-24s %-15s %-10s %-10s %-10s %s\n", created_at, updated_at, id, c_id, p_id, complete, version
    end

    def print_total(header, total)
      printf "%-20s %s\n", header, total
    end

    start_date = args[:start_date]&.to_date || 30.days.ago.utc
    end_date = args[:end_date]&.to_date || Time.zone.now.utc

    puts '------------------------------------------------------------'
    print_row(
      'created at:', 'updated at:', 'submission id:', 'claim id:',
      'participant id:', 'workflow complete:', 'form version:'
    )

    submissions = Form526Submission.where(
      'created_at BETWEEN ? AND ?', start_date.beginning_of_day, end_date.end_of_day
    )

    outage_errors = 0
    other_errors = 0

    # Scoped order are ignored for find_each. Its forced to be batch order (on primary key)
    # This should be fine as created_at dates correlate directly to PKs
    submissions.find_each do |submission|
      version = 'version 1: IO'
      submission.form526_job_statuses.each do |job_status|
        version = 'version 2: AC' if job_status.job_class == 'SubmitForm526AllClaim'
        if (job_status.job_class == 'SubmitForm526IncreaseOnly' || job_status.job_class == 'SubmitForm526AllClaim') &&
           job_status.error_message.present?
          job_status.error_message.include?('.serviceError') ? (outage_errors += 1) : (other_errors += 1)
        end
      end
      auth_headers = JSON.parse(submission.auth_headers_json)
      print_row(
        submission.created_at, submission.updated_at, submission.id, submission.submitted_claim_id,
        auth_headers['va_eauth_pid'], submission.workflow_complete, version
      )
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
  end

  desc 'Show all v1 forms'
  task show_v1: :environment do
    def print_row(created_at, updated_at, id)
      printf "%-24s %-24s %s\n", created_at, updated_at, id
    end

    def print_total(header, total)
      printf "%-20s %s\n", header, total
    end

    progress_forms = InProgressForm.where(form_id: '21-526EZ').order(:created_at)

    puts '------------------------------------------------------------'
    print_row('created at:', 'updated at:', 'id:')

    total_v1_forms = 0
    progress_forms.each do |progress_form|
      form_data = JSON.parse(progress_form.form_data)
      if form_data['veteran'].present?
        total_v1_forms += 1
        print_row(progress_form.created_at, progress_form.updated_at, progress_form.id)
      end
    end

    puts '------------------------------------------------------------'
    print_total('Total V1 forms:', total_v1_forms)
  end

  desc 'Get an error report within a given date period. [<start date: yyyy-mm-dd>,<end date: yyyy-mm-dd>]'
  task :errors, %i[start_date end_date] => [:environment] do |_, args|
    def print_row(sub_id, p_id, created_at)
      printf "%-20s %-20s %s\n", sub_id, p_id, created_at
      # rubocop:enable Style/FormatStringToken
    end

    def print_errors(errors)
      errors.each do |k, v|
        puts k
        puts '*****************'
        puts "Unique Participant ID count: #{v[:participant_ids].count}"
        print_row('submission_id:', 'participant_id:', 'created_at:')
        v[:submission_ids].each do |submission|
          print_row(submission[:sub_id], submission[:p_id], submission[:date])
        end
        puts '*****************'
        puts ''
      end
    end

    def clean_message(msg)
      if msg[1].present?
        # strip the GUID from BGS errors for grouping purposes
        "#{msg[0]}: #{msg[1].gsub(/GUID.*/, '')}"
      else
        msg[0]
      end
    end

    # This regex will parse out the errors returned from EVSS.
    # The error message will be in an ugly stringified hash. There can be multiple
    # errors in a message. Each error will have a `key` and a `text` key. The
    # following regex will group all key/text pairs together that are present in
    # the string.
    MSGS_REGEX = /key\"=>\"(.*?)\".*?text\"=>\"(.*?)\"/.freeze

    start_date = args[:start_date]&.to_date || 30.days.ago.utc
    end_date = args[:end_date]&.to_date || Time.zone.now.utc

    errors = Hash.new { |hash, message_name| hash[message_name] = { submission_ids: [], participant_ids: Set[] } }

    submissions = Form526Submission.where(
      'created_at BETWEEN ? AND ?', start_date.beginning_of_day, end_date.end_of_day
    )

    submissions.find_each do |submission|
      auth_headers = JSON.parse(submission.auth_headers_json)
      submission.form526_job_statuses.each do |job_status|
        next if job_status.error_class.blank?

        # Check if its an EVSS error and parse, otherwise store the entire message
        messages = if job_status.error_message.include?('=>') &&
                      job_status.error_class != 'Common::Exceptions::BackendServiceException'
                     job_status.error_message.scan(MSGS_REGEX)
                   else
                     [[job_status.error_message]]
                   end
        messages.each do |msg|
          message = clean_message(msg)
          errors[message][:submission_ids].append(
            sub_id: submission.id,
            p_id: auth_headers['va_eauth_pid'],
            date: submission.created_at
          )
          errors[message][:participant_ids].add(auth_headers['va_eauth_pid'])
        end
      end
    end

    puts '------------------------------------------------------------'
    puts "* Form526 Submission Errors from #{start_date} to #{end_date} *"
    puts '------------------------------------------------------------'
    puts ''
    print_errors(errors)
  end

  desc 'Get one or more submission details given an array of ids (either submission_ids or job_ids)'
  task submission: :environment do |_, args|
    raise 'No submission ids provided' unless args.extras.count.positive?

    def integer?(obj)
      obj.to_s == obj.to_i.to_s
    end
    Rails.application.eager_load!

    args.extras.each do |id|
      submission = if integer?(id)
                     Form526Submission.find(id)
                   else
                     Form526JobStatus.where(job_id: id).first.form526_submission
                   end

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

  desc 'update all disability compensation claims to have the correct type'
  task update_types: :environment do
    # `update_all` is being used because the `type` field will reset to `SavedClaim::DisabilityCompensation`
    # if a `claim.save` is done
    # rubocop:disable Rails/SkipsModelValidations
    SavedClaim::DisabilityCompensation.where(type: 'SavedClaim::DisabilityCompensation')
                                      .update_all(type: 'SavedClaim::DisabilityCompensation::Form526IncreaseOnly')
    # rubocop:enable Rails/SkipsModelValidations
  end
end
