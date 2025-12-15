# frozen_string_literal: true

require 'csv'
require 'date'

require 'reports/uploader'

# Used to provide feedback while processing
# a collection of Form526Submission instances.
@form526_verbose = ENV.key?('FORM526_VERBOSE')

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

    unless defined? F526_ROW
      F526_ROW = {
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
    end

    unless defined? F526_OPTIONS_STRUCT
      F526_OPTIONS_STRUCT = Struct.new(
        :print_header,
        :print_hr,
        :print_row,
        :print_total,
        :ignore_submission,
        :submissions,
        :success_failure_totals_header_string,
        keyword_init: true
      )
    end

    def date_range_mode(args_array)
      start_date = args_array.first&.to_date || 30.days.ago.utc
      end_date = args_array.second&.to_date || Time.zone.now.utc
      separator = ' '
      printf_string = F526_ROW[:order].map { |key| F526_ROW[:format_strings][key] }.join(separator)
      print_row = ->(**fields) { puts format(printf_string, *F526_ROW[:order].map { |key| fields[key] }) }

      F526_OPTIONS_STRUCT.new(
        print_header: -> { print_row.call(**F526_ROW[:headers]) },
        print_hr: -> { puts '------------------------------------------------------------' },
        print_row:,
        print_total: ->(header, total) { puts format("%-20s#{separator}%s", "#{header}:", total) },
        ignore_submission: ->(_) { false },
        submissions: Form526Submission.where(created_at: [start_date.beginning_of_day..end_date.end_of_day]),
        success_failure_totals_header_string: "* Job Success/Failure counts between #{start_date} - #{end_date} *"
      )
    end

    def bdd_stats_mode(args_array)
      dates = dates_from_array args_array
      # rubocop:disable Layout/LineLength
      prnt = ->(**fields) { puts F526_ROW[:order].map { |key| fields[key].try(:iso8601) || fields[key].inspect }.join(',') }
      # rubocop:enable Layout/LineLength
      F526_OPTIONS_STRUCT.new(
        print_header: -> { puts F526_ROW[:order].map { |key| F526_ROW[:headers][key] }.join(',') },
        print_hr: -> { puts },
        print_row: (
          if unredacted_flag_present?(args_array)
            prnt
          else
            ->(**fields) { prnt.call(**fields.merge(p_id: "*****#{fields[:p_id].to_s[5..]}")) }
          end
        ),
        print_total: ->(header, total) { puts "#{header.to_s.strip},#{total}" },
        ignore_submission: ->(submission) { submission.bdd? ? false : submission.id },
        submissions: Form526Submission.where(created_at: [
                                               (((dates.first || '2020-11-01'.to_date).beginning_of_day)..
                                               ((dates.second || (Time.zone.now.utc + 1.day)).end_of_day))
                                             ]),
        success_failure_totals_header_string: '* Job Success/Failure counts *'
      )
    end

    def bdd_stats_mode_dates_from_args(args)
      args_array = args.values_at :first, :second, :third
      return [] unless bdd_flag_present? args_array

      dates = dates_from_array args_array
      start_date = dates.first || '2020-11-01'.to_date
      end_date = dates.second || (Time.zone.now.utc + 1.day)
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

      submission.form526_job_statuses.where.not(error_message: [nil, '']).find_each do |job_status|
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
        version:
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
    # rubocop:disable Metrics/ParameterLists
    def print_row(sub_id, evss_id, user_uuid, created_at, is_bdd, job_class)
      printf "%-15s %-45s %-35s %-25s %-10s %-20s\n", sub_id, evss_id, user_uuid, created_at, is_bdd, job_class
    end

    # rubocop:enable Metrics/ParameterLists
    # rubocop:enable Style/FormatStringToken
    def print_errors(errors)
      errors.sort_by { |_message, hash| -hash[:submission_ids].length }.each do |(k, v)|
        puts k
        puts '*****************'
        puts "Unique Participant ID count: #{v[:participant_ids].count}"
        print_row('submission_id:', 'evss_id', 'user_uuid', 'created_at:', 'is_bdd?', 'job_class')
        v[:submission_ids].each do |submission|
          print_row(submission[:sub_id],
                    submission[:evss_id],
                    submission[:user_uuid],
                    submission[:date],
                    submission[:is_bdd],
                    submission[:job_class])
        end
        puts '*****************'
        puts ''
      end
    end

    def message_string(msg)
      return nil if msg['severity'] == 'WARN'

      message = msg['key']&.gsub(/\[(\d*)\]|\\/, '')
      # strip the GUID from BGS errors for grouping purposes

      # don't show disability names, for better grouping. Can be removed after we fix inflection issue
      unless message == 'form526.treatments.treatedDisabilityNames.isInvalidValue'
        message += msg['text'].gsub(/GUID.*/, '')
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
                      job_status.error_message.exclude?('BackendServiceException')
                     JSON.parse(job_status.error_message.gsub('=>', ':')).collect { |message| message_string(message) }
                   else
                     [job_status.error_message]
                   end
        messages.each do |message|
          errors[message][:submission_ids].append(
            sub_id: submission.id,
            p_id: submission.auth_headers['va_eauth_pid'],
            evss_id: submission.auth_headers['va_eauth_service_transaction_id'],
            user_uuid: submission.user_uuid,
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
        puts s.job_class
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

  # context in https://github.com/department-of-veterans-affairs/va.gov-team/issues/29651
  desc 'get a csv of all vets affected by BIRLS id mismatch errors since date'
  task :birls_errors, [:start_date] => [:environment] do |_, args|
    start_date = args[:start_date]&.to_date || 30.days.ago.utc
    fss = Form526JobStatus.where(status: 'exhausted',
                                 updated_at: [start_date..Time.now.utc])
    CSV.open('tmp/birls_errors.csv', 'wb') do |csv|
      csv << %w[veteran_name edipi birls_id ssn]
      fss.each do |form_status|
        fs = form_status.submission
        next unless fs

        ssn = fs.auth_headers['va_eauth_pnid']
        birls_id = fs.auth_headers['va_eauth_birlsfilenumber']
        edipi = fs.auth_headers['va_eauth_dodedipnid']
        vname = "#{fs.auth_headers['va_eauth_firstName']} #{fs.auth_headers['va_eauth_lastName']}"

        diff =  StringHelpers.levenshtein_distance(birls_id, ssn)
        csv << [vname, edipi, birls_id, ssn] if diff.positive? && diff < 3
      end
    end
    puts 'tmp/birls_errors.csv'
  end

  # context in https://github.com/department-of-veterans-affairs/va.gov-team/issues/11353
  desc 'get a csv of all vets affected by payee code errors with multiple corp ids since date'
  task :corp_id_errors, [:start_date] => [:environment] do |_, args|
    start_date = args[:start_date]&.to_date || 30.days.ago.utc
    fss = Form526JobStatus.where(status: 'non_retryable_error',
                                 updated_at: [start_date..Time.now.utc]).where("error_message like '%Payee code%'")
    file_path = 'tmp/corp_errors.csv'
    edipis = []
    CSV.open(file_path, 'wb') do |csv|
      csv << %w[veteran_name edipi corp_ids]
      fss.each do |form_status|
        fs = form_status.submission
        next unless fs

        edipi = fs.auth_headers['va_eauth_dodedipnid']
        if edipis.include? edipi
          next
        else
          edipis << edipi
        end

        response = MPI::Service.new.find_profile_by_edipi(edipi:).profile
        active_corp_ids = response.full_mvi_ids.grep(/\d*\^PI\^200CORP\^USVBA\^A/)
        vname = "#{fs.auth_headers['va_eauth_firstName']} #{fs.auth_headers['va_eauth_lastName']}"
        csv << [vname, edipi, active_corp_ids] if active_corp_ids.count > 1
      end
    end
    puts file_path
  end

  desc 'get a csv of all vets affected by PIF errors since date'
  task :pif_errors,  [:start_date] =>  [:environment] do |_, args|
    start_date = args[:start_date]&.to_date || 30.days.ago.utc
    fss = Form526JobStatus.where(status: 'exhausted',
                                 updated_at: [start_date..Time.now.utc]).where("error_message like '%PIF%'")
    ssns = []
    CSV.open('tmp/pif_errors.csv', 'wb') do |csv|
      csv << %w[veteran_name ssn soj form526_submission_id]
      fss.each do |form_status|
        fs = form_status.submission

        ssn = fs.auth_headers['va_eauth_pnid']

        if ssns.include? ssn
          next
        else
          ssns << ssn
        end

        vname = "#{fs.auth_headers['va_eauth_firstName']} #{fs.auth_headers['va_eauth_lastName']}"
        icn = fs.user_account&.icn
        if icn.blank?
          mpi_response = MPI::Service.new.find_profile_by_edipi(edipi: fs['va_eauth_dodedipnid'])
          if mpi_response.ok? && mpi_response.profile.icn.present?
            icn = mpi_response.profile.icn
          else
            puts "icn blank #{fs.id}"
            next
          end
        end
        user = OpenStruct.new(participant_id: fs.auth_headers['va_eauth_pid'], icn:, common_name: vname,
                              ssn:)
        award_response = BGS::AwardsService.new(user).get_awards
        if award_response
          soj = award_response[:award_stn_nbr]
        else
          addr = fs.form.dig('form526', 'form526', 'veteran', 'currentMailingAddress')
          soj = BGS::Service.new(user).get_regional_office_by_zip_code(addr['zipFirstFive'], addr['country'],
                                                                       addr['state'], 'CP', ssn)
        end
        row = [vname, ssn, soj]
        csv << row
        row
      rescue
        puts "failed for #{form_status.id}"
      end
    end
    puts 'csv complete in tmp/pif_errors.csv'
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

  desc 'Convert SIP data to camel case and fix checkboxes [/export/path.csv]'
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
      new_conditions = form_data_hash['newDisabilities']&.pluck('condition') || []
      rated_disabilities = form_data_hash['ratedDisabilities']&.pluck('name') || []
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

        in_progress_form.save!
      end
    end
  end

  desc 'pretty print MPI profile for submission'
  task mpi: :environment do |_, args|
    def puts_mpi_profile(submission)
      edipi = submission.auth_headers['va_eauth_dodedipnid']
      raise Error, 'no edipi' unless edipi

      ids = { edipi:, icn: submission.user_account&.icn }

      pp mpi_profile(ids).as_json
    end

    def mpi_profile(ids)
      if ids[:icn]
        find_profile_response = MPI::Service.new.find_profile_by_identifier(identifier: ids[:icn],
                                                                            identifier_type: MPI::Constants::ICN)
      else
        find_profile_response = MPI::Service.new.find_profile_by_edipi(edipi: ids[:edipi])
      end
      raise find_profile_response.error if find_profile_response.error

      find_profile_response.profile
    end

    Form526Submission.where(id: args.extras).find_each { |sub| puts_mpi_profile sub }
  end

  # Check a selected collection of form526_submissions
  # (class: Form526Submission) for valid form526 content.
  #
  desc 'Check selected form526 submissions for errors'
  task :lh_validate, %i[local_file start_date end_date] => :environment do |task_name, args|
    params = args.to_h

    unless (2..3).include?(params.size)
      abort_with_message <<~USAGE
        Send records from the form526_submissions table through
        the lighthouse validate endpoint selecting records based
        on their created_at timestamp.  Produces a CSV
        file that shows the results.

        Usage: bundle exec rake #{task_name}[local_file,YYYYMMDD,YYYYNNDD]

        local_file(String) when 'local' the CSV file is saved to
        the local file system.  Otherwise it is uploaded to S3.

          The filename will be in the form of
          "form526_YYYY-MM-DD_YYYY-MM-DD_validation.csv" using the
          start and end dates.  If the end date is not
          provided the value "9999-99-99" will be used
          in the file name.

        These two parameters control which records from the
        form526_submissions table are selected based upon
        the record's created_at value.

        start_date(YYYYMMDD)
        end_date(YYYYMMDD) **Optional**

          When the end date is not provided the selections
          of records will be on or after start date.
          When present the query is between start and end dates inclusive.

        form526_verbose? is #{form526_verbose?}
        Export or unset system environment variable FORM526_VERGOSE as desired
        to get feedback while processing records.
      USAGE
    end

    @local_file = validate_local_file(params[:local_file])
    start_date  = validate_yyyymmdd(params[:start_date])
    end_date    = (validate_yyyymmdd(params[:end_date]) if params[:end_date])

    if params.size == 3 && (start_date > end_date)
      abort_with_message "ERROR:  start_date (#{start_date}) is after end_date (#{end_date})"
    end

    csv_filename  = "form526_#{start_date}_#{end_date || '9999-99-99'}_validation.csv"
    csv_header    = %w[RecID Original Valid? Error]

    # SMELL:  created_at is not indexed
    #         Not a problem because this is
    #         a manually launched task with
    #         an expected low number of records

    submissions = if end_date.nil?
                    Form526Submission.where('created_at >= ?', start_date)
                  else
                    Form526Submission.where(created_at: start_date..end_date)
                  end

    csv_content = CSV.generate do |csv|
      csv << csv_header

      submissions.each do |submission|
        base_row   = [submission.id]
        base_row  << original_success_indicator(submission)
        base_row  << submission.form_content_valid?

        # if it was valid then append no errors and
        # do the next submission
        if base_row.last
          base_row << ''
          csv << base_row
          puts base_row.join(', ') if form526_verbose?
          next
        end

        errors = submission.lighthouse_validation_errors

        if form526_verbose?
          print base_row.join(', ')
          puts " has #{errors.size} errors."
        end

        errors.each do |error|
          row   = base_row.dup
          row  << error['title']
          csv << row
          next
        end
      end
    end

    print "Saving #{csv_filename} " if form526_verbose?

    if local_file?
      print '... ' if form526_verbose?
      csv_file = File.new(csv_filename, 'w')
      csv_file.write csv_content
      csv_file.close
    else
      print 'to S3 ... ' if form526_verbose?

      s3_resource   = Reports::Uploader.new_s3_resource
      target_bucket = Reports::Uploader.s3_bucket
      object        = s3_resource.bucket(target_bucket).object(csv_filename)

      object.put(body: csv_content)
    end

    puts 'Done.' if form526_verbose?
  end

  ############################################
  ## Utility Methods

  def validate_local_file(a_string) = a_string.downcase == 'local'
  def local_file?                   = @local_file

  # Ensure that a date string is correctly formatted
  # Returns a Date object
  # abort if invalid
  def validate_yyyymmdd(a_string)
    if a_string.match?(/\A[0-9]{8}\z/)
      begin
        Date.strptime(a_string, '%Y%m%d')
      rescue Date::Error
        abort_with_message "ERROR: bad date (#{a_string}) must be 8 digits in format YYYYMMDD"
      end
    else
      abort_with_message "ERROR: bad date (#{a_string}) must be 8 digits in format YYYYMMDD"
    end
  end

  # Send error message to STDOUT and
  # then abort
  #
  def abort_with_message(a_string)
    print "\n#{a_string}\n\n"
    abort
  end

  def form526_verbose?
    @form526_verbose
  end

  # Use the form526_job_statuses has_many link
  # to get the OSI value
  #
  def original_success_indicator(a_submission_record)
    job_status = a_submission_record
                 .form526_job_statuses
                 .order(:updated_at)
                 .pluck(:job_class, :status)
                 .to_h

    if job_status.empty?
      'Not Processed'
    elsif job_status['SubmitForm526AllClaim'] == 'success'
      'Primary Success'
    elsif job_status['BackupSubmission'] == 'success'
      'Backup Success'
    else
      'Unknown'
    end
  end
end
