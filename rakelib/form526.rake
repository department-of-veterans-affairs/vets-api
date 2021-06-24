# frozen_string_literal: true

require 'pp'
require 'set'

namespace :form526 do
  desc <<~HEREDOC
    Get all submissions within a date period:
      rake form526:submissions[2021-01-23,2021-01-24]
    Last 30 days:
      rake form526:submissions[]
    BDD stats mode: (argument order doesn't matter)
      rake form526:submissions[bdd]
      rake form526:submissions[bdd,2021-02-11] # this date and beyond
      rake form526:submissions[bdd,2021-02-10,2021-02-11]
      rake form526:submissions[bdd,2021-02-10,2021-02-11,unredacted]
  HEREDOC
  task submissions: :environment do |_, args|
    # rubocop:disable Style/FormatStringToken
    # This forces string token formatting. Our examples don't match
    # what this style is enforcing
    # rubocop: format('%<greeting>s', greeting: 'Hello')
    # vets-api example: printf "%-20s %s\n", header, total

    #####  RUN-IN-CONSOLE HELPER CODE  ####
    ## When pasting this task into a console, this snippet saves up the output to
    ## print at the very end (instead of being printed within the code your pasting).
    ## After playing around with $stdout, I found temporarily redefining "puts" more
    ## closely accomplishes the behavior I was trying to achieve.
    #
    # OUTPUT = ""
    # def puts(string = "")
    #   OUTPUT << string
    #   OUTPUT << "\n"
    # end
    #
    ## Set the args:
    #
    # args = { first: '2020-12-25' }
    # args[:second] = args[:first]
    #######################################

    ROW = {
      order: %i[created_at updated_at id c_id p_id complete version],
      format_strings: {
        created_at: '%-24s',
        updated_at: '%-24s',
        id: '%-15s',
        c_id: '%-10s',
        p_id: '%-15s',
        complete: '%-18s',
        version: '%s'
      },
      headers: {
        created_at: 'created at:',
        updated_at: 'updated at:',
        id: 'submission id:',
        c_id: 'claim id:',
        p_id: 'participant id:',
        complete: 'workflow complete:',
        version: 'form version:'
      }
    }.freeze
    OPTIONS_STRUCT = Struct.new(
      :print_header,
      :print_hr,
      :print_row,
      :print_total,
      :ignore_submission,
      :submissions,
      :success_failure_totals_header_string,
      keyword_init: true
    )
    def date_range_mode(args_array)
      start_date = args_array.first&.to_date || 30.days.ago.utc
      end_date = args_array.second&.to_date || Time.zone.now.utc
      separator = ' '
      printf_string = ROW[:order].map { |key| ROW[:format_strings][key] }.join(separator)
      print_row = ->(**fields) { puts format(printf_string, *ROW[:order].map { |key| fields[key] }) }

      OPTIONS_STRUCT.new(
        print_header: -> { print_row.call(**ROW[:headers]) },
        print_hr: -> { puts '------------------------------------------------------------' },
        print_row: print_row,
        print_total: ->(header, total) { puts format("%-20s#{separator}%s", "#{header}:", total) },
        ignore_submission: ->(_) { false },
        submissions: Form526Submission.where(created_at: [start_date.beginning_of_day..end_date.end_of_day]),
        success_failure_totals_header_string: "* Job Success/Failure counts between #{start_date} - #{end_date} *"
      )
    end

    def bdd_stats_mode(args_array)
      dates = dates_from_array args_array
      prnt = ->(**fields) { puts ROW[:order].map { |key| fields[key].try(:iso8601) || fields[key].inspect }.join(',') }
      OPTIONS_STRUCT.new(
        print_header: -> { puts ROW[:order].map { |key| ROW[:headers][key] }.join(',') },
        print_hr: -> { puts },
        print_row: (
          if unredacted_flag_present?(args_array)
            prnt
          else
            ->(**fields) { prnt.call(**fields.merge(p_id: '*****' + fields[:p_id].to_s[5..])) }
          end
        ),
        print_total: ->(header, total) { puts "#{header.to_s.strip},#{total}" },
        ignore_submission: ->(submission) { submission.bdd? ? false : submission.id },
        submissions: Form526Submission.where(created_at: [
                                               (dates.first || '2020-11-01'.to_date).beginning_of_day..
                                               (dates.second || Time.zone.now.utc + 1.day).end_of_day
                                             ]),
        success_failure_totals_header_string: '* Job Success/Failure counts *'
      )
    end

    def bdd_stats_mode_dates_from_args(args)
      args_array = args.values_at :first, :second, :third
      return [] unless bdd_flag_present? args_array

      dates = dates_from_array args_array
      start_date = dates.first || '2020-11-01'.to_date
      end_date = dates.second || Time.zone.now.utc + 1.day
      [start_date, end_date]
    end

    def missing_dates_as_zero(hash_with_date_keys)
      dates = hash_with_date_keys.keys.sort
      return {} if dates.blank?

      earliest_date = dates.first
      latest_date = dates.last
      raise unless earliest_date.to_date <= latest_date.to_date

      new_hash = {}
      date = earliest_date
      loop do
        new_hash[date] = hash_with_date_keys[date] || 0
        break if date == latest_date

        date = tomorrow date
      end

      new_hash
    end

    def to_date_string(value)
      value.try(:to_date)&.iso8601
    end

    def tomorrow(date_string)
      to_date_string date_string.to_date.tomorrow
    end

    def bdd_flag_present?(array)
      flag_present_in_array? 'bdd', array
    end

    def unredacted_flag_present?(array)
      flag_present_in_array? 'unr', array
    end

    def flag_present_in_array?(flag, array)
      array.any? { |value| value&.to_s&.downcase&.include? flag }
    end

    def dates_from_array(array)
      dates = []
      array.each do |value|
        date = begin
                 value.to_date
               rescue
                 nil
               end
        dates << date if date
      end
      dates
    end

    options = bdd_flag_present?(args.extras) ? bdd_stats_mode(args.extras) : date_range_mode(args.extras)

    options.print_hr.call
    options.print_header.call

    outage_errors = 0
    ancillary_job_errors = Hash.new 0
    other_errors = 0
    submissions_per_day = Hash.new 0
    ids_to_ignore = []

    # Scoped order are ignored for find_each. Its forced to be batch order (on primary key)
    # This should be fine as created_at dates correlate directly to PKs
    options.submissions.find_each do |submission|
      if (id_to_ignore = options.ignore_submission.call(submission))
        ids_to_ignore << id_to_ignore
        next
      end

      submissions_per_day[to_date_string(submission.created_at)] += 1

      submission.form526_job_statuses.where.not(error_message: [nil, '']).each do |job_status|
        if job_status.job_class == 'SubmitForm526AllClaim'
          job_status.error_message.include?('.serviceError') ? (outage_errors += 1) : (other_errors += 1)
        else
          ancillary_job_errors[job_status.job_class] += 1
        end
      end
      version = submission.bdd? ? 'BDD' : 'ALL'
      options.print_row.call(
        created_at: submission.created_at,
        updated_at: submission.updated_at,
        id: submission.id,
        c_id: submission.submitted_claim_id,
        p_id: submission.auth_headers['va_eauth_pid'],
        complete: submission.workflow_complete,
        version: version
      )
    end
    options.submissions = options.submissions.where.not(id: ids_to_ignore) if ids_to_ignore.present?

    total_jobs = options.submissions.count
    success_jobs = options.submissions.where(workflow_complete: true)
    success_jobs_count = success_jobs.count

    fail_jobs = total_jobs - success_jobs.count

    total_users_submitting = options.submissions.count('DISTINCT user_uuid')
    total_successful_users_submitting = success_jobs.count('DISTINCT user_uuid')

    user_success_rate = (total_successful_users_submitting.to_f / total_users_submitting)

    options.print_hr.call
    puts options.success_failure_totals_header_string
    options.print_total.call('Total Jobs', total_jobs)
    options.print_total.call('Successful Jobs', success_jobs_count)
    options.print_total.call('Failed Jobs', fail_jobs)
    options.print_total.call('User Success Rate', user_success_rate)

    options.print_hr.call
    options.print_total.call('Total Users Submitted', total_users_submitting)
    options.print_total.call('Total Users Submitted Successfully', total_successful_users_submitting)
    options.print_total.call('User Success rate', user_success_rate)

    options.print_hr.call
    puts '* Failure Counts for form526 Submission Job (not including uploads/cleanup/etc...) *'
    options.print_total.call('Outage Failures', outage_errors)
    options.print_total.call('Other Failures', other_errors)
    puts 'Ancillary Job Errors:'
    ancillary_job_errors.each do |class_name, error_count|
      options.print_total.call "    #{class_name}", error_count
    end

    options.print_hr.call
    puts '* Daily Totals *'
    missing_dates_as_zero(submissions_per_day).each do |date, submission_count|
      options.print_total.call date, submission_count
    end

    ####  RUN-IN-CONSOLE HELPER CODE  ####
    # STDOUT.puts OUTPUT;nil
    ######################################
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
      submit_jobs = submission.form526_job_statuses.where(
        job_class: Form526Submission::SUBMIT_FORM_526_JOB_CLASSES
      )

      ancillary_jobs = submission.form526_job_statuses.where.not(
        job_class: Form526Submission::SUBMIT_FORM_526_JOB_CLASSES
      )

      unsuccessful_submit_jobs, unsuccessful_ancillary_jobs = [submit_jobs, ancillary_jobs].map do |jobs|
        jobs.where.not status: [Form526JobStatus::STATUS[:try], Form526JobStatus::STATUS[:success]]
      end

      in_progress_submit_jobs = submit_jobs.where status: Form526JobStatus::STATUS[:try]

      the_submission_has_been_successfully_submitted = submission.a_submit_form_526_job_succeeded?

      it_is_still_trying = in_progress_submit_jobs.present?

      # we're not interested in unsuccessful submit jobs if submit eventually succeeded (or is still being attempted)
      unsuccessful_jobs = if the_submission_has_been_successfully_submitted || it_is_still_trying
                            unsuccessful_ancillary_jobs
                          else
                            unsuccessful_ancillary_jobs.or unsuccessful_submit_jobs
                          end

      unsuccessful_jobs.each do |job_status|
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

    # We want the original version of the string, downcased as the json key for checkboxes
    def get_dis_translation_hash(disability_array)
      dis_translation_hash = {}
      disability_array.each do |dis|
        dis_translation_hash[simplify_string(dis)] = dis&.downcase
      end
      dis_translation_hash
    end

    def fix_treatment_facilities_disability_name(form_data_hash, dis_translation_hash)
      transformed = false
      # fix vaTreatmentFacilities -> treatedDisabilityNames
      # this should never happen, just want to confirm
      form_data_hash['vaTreatmentFacilities']&.each do |va_treatment_facilities|
        new_treated_disability_names = {}
        if va_treatment_facilities['treatedDisabilityNames']
          va_treatment_facilities['treatedDisabilityNames'].each do |disability_name, value|
            if dis_translation_hash.values.include? disability_name
              new_treated_disability_names[disability_name] = value
            else
              transformed = true
              original_disability_name = dis_translation_hash[simplify_string(disability_name)]
              new_treated_disability_names[original_disability_name] = value unless original_disability_name.nil?
            end
          end
          va_treatment_facilities['treatedDisabilityNames'] = new_treated_disability_names
        end
      end
      transformed
    end

    def fix_pow_disabilities(form_data_hash, dis_translation_hash)
      transformed = false
      # just like treatedDisabilityNames fix the same checkbox data for POW disabilities
      pow_disabilities = form_data_hash.dig('view:isPow', 'powDisabilities')
      if pow_disabilities
        new_pow_disability_names = {}
        pow_disabilities.each do |disability_name, value|
          if dis_translation_hash.values.include? disability_name
            new_pow_disability_names[disability_name] = value
          else
            transformed = true
            original_disability_name = dis_translation_hash[simplify_string(disability_name)]
            new_pow_disability_names[original_disability_name] = value unless original_disability_name.nil?
          end
        end
        form_data_hash['view:isPow']['powDisabilities'] = new_pow_disability_names
      end
      transformed
    end
    # get all of the forms that have not yet been converted.
    ipf = InProgressForm.where(form_id: FormProfiles::VA526ez::FORM_ID)

    in_progress_forms = if ids.present?
                          ipf.where(id: ids)
                        else
                          ipf.where("metadata -> 'return_url' is not null")
                        end

    CSV.open(args[:csv_path], 'wb') do |csv|
      csv << %w[in_progress_form_id in_progress_form_user_uuid email_address]
      in_progress_forms.each do |in_progress_form|
        in_progress_form.metadata = to_olivebranch_case(in_progress_form.metadata)
        form_data_hash = un_camel_va_keys!(to_olivebranch_case(JSON.parse(in_progress_form.form_data)))
        disability_array = get_disability_array(form_data_hash)
        dis_translation_hash = get_dis_translation_hash(disability_array)

        treatment_facilities_transformed = fix_treatment_facilities_disability_name(form_data_hash,
                                                                                    dis_translation_hash)
        pow_transformed = fix_pow_disabilities(form_data_hash,
                                               dis_translation_hash)

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

  desc 'pretty print MPI profile for submission'
  task mpi: :environment do |_, args|
    def puts_mpi_profile(submission)
      ids = {}
      ids[:edipi] = edipi submission.auth_headers
      ids[:icn] = icn ids[:edipi]

      pp mpi_profile(user_identity(**ids)).as_json
    end

    def mpi_profile(user_identity)
      find_profile_response = MPI::Service.new.find_profile user_identity
      raise find_profile_response.error if find_profile_response.error

      find_profile_response.profile
    end

    def user_identity(icn:, edipi:)
      OpenStruct.new mhv_icn: icn, edipi: edipi
    end

    def edipi(auth_headers)
      auth_headers['va_eauth_dodedipnid']
    end

    def icn(edipi)
      raise Error, 'no edipi' unless edipi

      icns = Account.where(edipi: edipi).pluck :icn
      raise Error, 'multiple icns' if icns.uniq.length > 1

      icns.first
    end

    Form526Submission.where(id: args.extras).each { |sub| puts_mpi_profile sub }
  end
end
