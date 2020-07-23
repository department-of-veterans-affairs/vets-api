# frozen_string_literal: true

module BGS
  class DependentService
    include SentryLogging

    def initialize(user)
      @user = user
    end

    def get_dependents
      service.claimants.find_dependents_by_participant_id(@user.participant_id, @user.ssn)
    end

    def submit_686c_form(payload)
      va_file_number_with_payload = add_va_file_number_to_payload(payload.to_h)


    rescue => e
      report_error(e)
    end

    private

    def service
      external_key = @user.common_name || @user.email

      @service ||= BGS::Services.new(
        external_uid: @user.icn,
        external_key: external_key
      )
    end

    def add_va_file_number_to_payload(payload)
      va_file_number = service.people.find_person_by_ptcpnt_id(@user.participant_id)

      payload[:veteran_contact_information][:va_file_number] = va_file_number[:file_nbr]

      payload
    end

    def veteran_hash
      {
        participant_id: @user.participant_id,
        ssn: @user.ssn,
        first_name: @user.first_name,
        last_name: @user.last_name,
        email: @user.email,
        external_key: @user.common_name || @user.email,
        icn: @user.icn
      }
    end

    def report_error(error)
      log_exception_to_sentry(
        error,
        {
          icn: @user.icn
        },
        { team: 'vfs-ebenefits' }
      )
    end

    def to_pdf(current_user, dependents_hash, claim)
      veteran_info = {
        'veteran_information' => {
          'full_name' => {
            'first' => current_user.first_name,
            'middle' => current_user.middle_name,
            'last' => current_user.last_name # ,
            # "suffix" => "Jr."
          },
          'ssn' => current_user.ssn,
          # "va_file_number" => "796104437",
          # "service_number" => "12345678",
          'birth_date' => current_user.birth_date
        }
      }

      claim.parsed_form.merge!(veteran_info)
      PdfFill::Filler.fill_form(claim)
    end

    def upload_to_vbms(current_user, path)
      uploader = ClaimsApi::VbmsUploader.new(
        filepath: path,
        file_number: current_user.ssn,
        doc_type: '148'
      )

      upload_response = uploader.upload!
    rescue VBMS::Unknown
      rescue_vbms_error(current_user)
    rescue Errno::ENOENT
      rescue_file_not_found(current_user)
    end

    def fetch_file_path(uploader)
      if Settings.evss.s3.uploads_enabled
        temp = URI.parse(uploader.file.url).open
        temp.path
      else
        uploader.file.file
      end
    end

    def rescue_file_not_found()
      # exception
      # need to add logging
    end

    def rescue_vbms_error()
      # exception
      # need to add logging
    end
  end
end
