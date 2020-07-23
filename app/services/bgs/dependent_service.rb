# frozen_string_literal: true

require 'claims_api/vbms_uploader'

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
      # va_file_number_with_payload = add_va_file_number_to_payload(payload.to_h)

      # VBMS::Form686cPdfJob.perform_async(veteran_hash, va_file_number_with_payload)

      output_path = to_pdf(claim)
      vbms_response = upload_to_vbms(@user, output_path)
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

    def to_pdf(claim)
      veteran_info = {
        'veteran_information' => {
          'full_name' => {
            'first' => @user.first_name,
            'middle' => @user.middle_name,
            'last' => @user.last_name # ,
            # "suffix" => "Jr."
          },
          'ssn' => @user.ssn,
          # "va_file_number" => "796104437",
          # "service_number" => "12345678",
          'birth_date' => @user.birth_date
        }
      }

      claim.parsed_form.merge!(veteran_info)
      PdfFill::Filler.fill_form(claim)
    end

    def upload_to_vbms(path)
      uploader = ClaimsApi::VbmsUploader.new(
        filepath: path,
        file_number: @user.ssn,
        doc_type: '148'
      )

      upload_response = uploader.upload!
    rescue VBMS::Unknown
      rescue_vbms_error(@user)
    rescue Errno::ENOENT
      rescue_file_not_found(@user)
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
