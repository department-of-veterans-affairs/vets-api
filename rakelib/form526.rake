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
      printf "%-24s %-24s %-15s %-10s %-15s %-18s %s\n", created_at, updated_at, id, c_id, p_id, complete, version
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

    submissions = Form526Submission.where(created_at: [start_date.beginning_of_day..end_date.end_of_day])

    outage_errors = 0
    ancillary_job_errors = Hash.new { |hash, job_class| hash[job_class] = 0 }
    other_errors = 0

    # Scoped order are ignored for find_each. Its forced to be batch order (on primary key)
    # This should be fine as created_at dates correlate directly to PKs
    submissions.find_each do |submission|
      submission.form526_job_statuses.where.not(error_message: [nil, '']).each do |job_status|
        if job_status.job_class == 'SubmitForm526AllClaim'
          job_status.error_message.include?('.serviceError') ? (outage_errors += 1) : (other_errors += 1)
        else
          ancillary_job_errors[job_status.job_class] += 1
        end
      end
      version = submission.bdd? ? 'BDD' : 'ALL'
      print_row(
        submission.created_at, submission.updated_at, submission.id, submission.submitted_claim_id,
        submission.auth_headers['va_eauth_pid'], submission.workflow_complete, version
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
    puts 'Ancillary Job Errors:'
    ancillary_job_errors.each do |class_name, error_count|
      puts "    #{class_name}: #{error_count}"
    end
  end

  desc 'Get an error report within a given date period. [<start date: yyyy-mm-dd>,<end date: yyyy-mm-dd>,<flag>]'
  task :errors, %i[start_date end_date flag] => [:environment] do |_, args|
    def print_row(sub_id, p_id, created_at, is_bdd, job_class)
      printf "%-15s %-16s  %-25s %-10s %-20s\n", sub_id, p_id, created_at, is_bdd, job_class
      # rubocop:enable Style/FormatStringToken
    end

    def print_errors(errors)
      errors.sort_by { |_message, hash| -hash[:submission_ids].length }.each do |(k, v)|
        puts k
        puts '*****************'
        puts "Unique Participant ID count: #{v[:participant_ids].count}"
        print_row('submission_id:', 'participant_id:', 'created_at:', 'is_bdd?', 'job_class')
        v[:submission_ids].each do |submission|
          print_row(submission[:sub_id],
                    submission[:p_id],
                    submission[:date],
                    submission[:is_bdd],
                    submission[:job_class])
        end
        puts '*****************'
        puts ''
      end
    end

    def message_string(msg)
      return nil if msg.dig('severity') == 'WARN'

      message = msg.dig('key')&.gsub(/\[(\d*)\]|\\/, '')
      # strip the GUID from BGS errors for grouping purposes

      # don't show disability names, for better grouping. Can be removed after we fix inflection issue
      unless message == 'form526.treatments.treatedDisabilityNames.isInvalidValue'
        message += msg.dig('text').gsub(/GUID.*/, '')
      end
      message
    end

    start_date = args[:start_date]&.to_date || 30.days.ago.utc
    end_date = args[:end_date]&.to_date || Time.zone.now.utc

    errors = Hash.new { |hash, message_name| hash[message_name] = { submission_ids: [], participant_ids: Set[] } }

    submissions = Form526Submission.where(
      'created_at BETWEEN ? AND ?', start_date.beginning_of_day, end_date.end_of_day
    )

    submissions.find_each do |submission|
      job_statuses = submission.form526_job_statuses.where.not(status: [Form526JobStatus::STATUS[:try],
                                                                        Form526JobStatus::STATUS[:success]])
      job_statuses.each do |job_status|
        # Check if its an EVSS error and parse, otherwise store the entire message
        messages = if job_status.error_message.include?('=>') &&
                      !job_status.error_message.include?('BackendServiceException')
                     JSON.parse(job_status.error_message.gsub('=>', ':')).collect { |message| message_string(message) }
                   else
                     [job_status.error_message]
                   end
        messages.each do |message|
          errors[message][:submission_ids].append(
            sub_id: submission.id,
            p_id: submission.auth_headers['va_eauth_pid'],
            date: submission.created_at,
            is_bdd: submission.bdd?,
            job_class: job_status.job_class
          )
          errors[message][:participant_ids].add(submission.auth_headers['va_eauth_pid'])
        end
      end
    end

    if args[:flag]&.downcase&.include?('j')
      puts errors.to_json
      next
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

      saved_claim_form = submission.saved_claim.parsed_form
      saved_claim_form['veteran'] = 'FILTERED'

      submitted_claim_form = submission.form
      submitted_claim_form['form526']['form526']['directDeposit'] = 'FILTERED'
      submitted_claim_form['form526']['form526']['veteran'] = 'FILTERED'

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
      puts "Form From User JSON:\n\n"
      puts JSON.pretty_generate(saved_claim_form)
      puts "\n\n"
      puts '----------------------------------------'
      puts "Translated form for EVSS JSON:\n\n"
      puts JSON.pretty_generate(submitted_claim_form)
      puts "\n\n"
    end
  end

  # EVSS has asked us to re-upload files that were corrupted upstream
  desc 'Resubmit uploads to EVSS for submitted claims given an array of saved_claim_ids'
  task retry_corrupted_uploads: :environment do |_, args|
    raise 'No saved_claim_ids provided' unless args.extras.count.positive?

    form_submissions = Form526Submission.where(saved_claim_id: args.extras)
    form_submissions.each do |form_submission|
      form_submission.send(:submit_uploads)
      puts "reuploaded files for saved_claim_id #{form_submission.saved_claim_id}"
    end
    puts "reuploaded files for #{form_submissions.count} submissions"
  end

  desc 'Convert SIP data to camel case and fix checkboxes [/export/path.csv, ids]'
  task :convert_sip_data, [:csv_path] => :environment do |_, args|
    raise 'No CSV path provided' unless args[:csv_path]

    ids = args.extras || []

    def to_olivebranch_case(val)
      OliveBranch::Transformations.transform(
        val,
        OliveBranch::Transformations.method(:camelize)
      )
    end

    def un_camel_va_keys!(hash)
      json = hash.to_json
      # rubocop:disable Style/PerlBackrefs
      # gsub with a block explicitly sets backrefs correctly https://ruby-doc.org/core-2.6.6/String.html#method-i-gsub
      json.gsub!(OliveBranch::Middleware::VA_KEY_REGEX) do
        key = $1
        "#{key.gsub('VA', 'Va')}:"
      end
      JSON.parse(json)
      # rubocop:enable Style/PerlBackrefs
    end

    def get_disability_array(form_data_hash)
      new_conditions = form_data_hash['newDisabilities']&.collect { |d| d.dig('condition') } || []
      rated_disabilities = form_data_hash['ratedDisabilities']&.collect { |rd| rd['name'] } || []
      new_conditions + rated_disabilities
    end

    # downcase and remove everything but letters and numbers
    def simplify_string(string)
      string&.downcase&.gsub(/[^a-z0-9]/, '')
    end

    def get_dis_translation_hash(disability_array)
      dis_translation_hash = {}
      disability_array.each do |dis|
        dis_translation_hash[simplify_string(dis)] = dis
      end
      dis_translation_hash
    end

    def fix_treatment_facilities_disability_name(form_data_hash, dis_translation_hash, disability_array)
      transformed = false
      # fix vaTreatmentFacilities -> treatedDisabilityNames
      # this should never happen, just want to confirm
      form_data_hash['vaTreatmentFacilities']&.each do |va_treatment_facilities|
        new_treated_disability_names = {}
        if va_treatment_facilities['treatedDisabilityNames']
          va_treatment_facilities['treatedDisabilityNames'].each do |disability_name, value|
            if disability_array.include? disability_name
              new_treated_disability_names[disability_name] = value
            else
              transformed = true
              original_disability_name = dis_translation_hash[simplify_string(disability_name)]&.downcase
              new_treated_disability_names[original_disability_name] = value unless original_disability_name.nil?
            end
          end
          va_treatment_facilities['treatedDisabilityNames'] = new_treated_disability_names
        end
      end
      transformed
    end

    def fix_pow_disabilities(form_data_hash, dis_translation_hash, disability_array)
      transformed = false
      # just like treatedDisabilityNames fix the same checkbox data for POW disabilities
      pow_disabilities = form_data_hash.dig('view:isPow', 'powDisabilities')
      if pow_disabilities
        new_pow_disability_names = {}
        pow_disabilities.each do |disability_name, value|
          if disability_array.include? disability_name
            new_pow_disability_names[disability_name] = value
          else
            transformed = true
            original_disability_name = dis_translation_hash[simplify_string(disability_name)]&.downcase
            new_pow_disability_names[original_disability_name] = value unless original_disability_name.nil?
          end
        end
        form_data_hash['view:isPow']['powDisabilities'] = new_pow_disability_names
      end
      transformed
    end
    # get all of the forms that have not yet been converted.
    ipf = InProgressForm.where(form_id: FormProfiles::VA526ez::FORM_ID)
    in_progress_forms = ipf.where("metadata -> 'return_url' is not null").or(ipf.where(id: ids))
    @affected_forms = []

    CSV.open(args[:csv_path], 'wb') do |csv|
      csv << %w[in_progress_form_id in_progress_form_user_uuid email_address]
      in_progress_forms.each do |in_progress_form|
        in_progress_form.metadata = to_olivebranch_case(in_progress_form.metadata)
        form_data_hash = un_camel_va_keys!(to_olivebranch_case(JSON.parse(in_progress_form.form_data)))
        disability_array = get_disability_array(form_data_hash)
        dis_translation_hash = get_dis_translation_hash(disability_array)

        treatment_facilities_transformed = fix_treatment_facilities_disability_name(form_data_hash,
                                                                                    dis_translation_hash,
                                                                                    disability_array)
        pow_transformed = fix_pow_disabilities(form_data_hash,
                                               dis_translation_hash,
                                               disability_array)

        fixed_va_inflection = OliveBranch::Middleware.send(:un_camel_va_keys!, form_data_hash.to_json)
        if treatment_facilities_transformed || pow_transformed
          csv << [in_progress_form.id,
                  in_progress_form.user_uuid,
                  form_data_hash.dig('phoneAndEmail', 'emailAddress')]
        end

        in_progress_form.form_data = fixed_va_inflection

        # forms expire a year after they're last saved by the user so we want to disable updating the expires_at.
        in_progress_form.skip_exipry_update = true
        in_progress_form.save!
      end
    end
  end
end
