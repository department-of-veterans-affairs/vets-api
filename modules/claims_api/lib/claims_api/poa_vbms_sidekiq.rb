# frozen_string_literal: true

require 'claims_api/vbms_uploader'
require 'bgs_service/person_web_service'
require 'vets/shared_logging'

module ClaimsApi
  module PoaVbmsSidekiq
    include Vets::SharedLogging

    def upload_to_vbms(power_of_attorney, path)
      uploader = VBMSUploader.new(
        filepath: path,
        file_number: retrieve_veteran_file_number(power_of_attorney:),
        doc_type: '295'
      )
      upload_response = uploader.upload!
      power_of_attorney.update(
        status: ClaimsApi::PowerOfAttorney::UPLOADED,
        vbms_new_document_version_ref_id: upload_response[:vbms_new_document_version_ref_id],
        vbms_document_series_ref_id: upload_response[:vbms_document_series_ref_id]
      )
    end

    def rescue_file_not_found(power_of_attorney, process: nil)
      error_message = 'File could not be retrieved from AWS'

      power_of_attorney.update(
        status: ClaimsApi::PowerOfAttorney::ERRORED,
        vbms_error_message: error_message
      )
      if process.present?
        process.update!(step_status: 'FAILED',
                        error_messages: [{ title: 'VBMS Error',
                                           detail: error_message }])
      end
    end

    def rescue_vbms_error(power_of_attorney, process: nil)
      power_of_attorney.vbms_upload_failure_count = power_of_attorney.vbms_upload_failure_count + 1
      power_of_attorney.vbms_error_message = 'An unknown error has occurred when uploading document'
      if process.present?
        process.update!(step_status: 'FAILED',
                        error_messages: [{ title: 'VBMS Error',
                                           detail: power_of_attorney.vbms_error_message }])
      end
      if power_of_attorney.vbms_upload_failure_count < 5
        self.class.perform_in(30.minutes, power_of_attorney.id)
      else
        power_of_attorney.status = ClaimsApi::PowerOfAttorney::ERRORED
      end
      power_of_attorney.save
    end

    def rescue_vbms_file_number_not_found(power_of_attorney)
      error_message = 'VBMS is unable to locate file number'
      power_of_attorney.update(
        status: ClaimsApi::PowerOfAttorney::ERRORED,
        vbms_error_message: error_message
      )
      log_message_to_sentry(self.class.name, :warning, body: error_message)
    end

    private

    def retrieve_veteran_file_number(power_of_attorney:)
      ssn = power_of_attorney.auth_headers['va_eauth_pnid']

      begin
        bgs_service(power_of_attorney:).find_by_ssn(ssn)&.[](:file_nbr) # rubocop:disable Rails/DynamicFindBy
      rescue BGS::ShareError => e
        error_message = "A BGS failure occurred while trying to retrieve Veteran 'FileNumber'"
        log_exception_to_sentry(e, nil, { message: error_message }, 'warn')
        raise ::Common::Exceptions::FailedDependency
      end
    end

    def bgs_service(power_of_attorney:)
      if Flipper.enabled? :claims_api_use_person_web_service
        ClaimsApi::PersonWebService.new(
          external_uid: power_of_attorney.auth_headers['va_eauth_pid'],
          external_key: power_of_attorney.auth_headers['va_eauth_pid']
        )
      else
        BGS::Services.new(
          external_uid: power_of_attorney.auth_headers['va_eauth_pid'],
          external_key: power_of_attorney.auth_headers['va_eauth_pid']
        ).people
      end
    end
  end
end
