# frozen_string_literal: true

require 'claims_api/vbms_uploader'

module ClaimsApi
  module VBMSSidekiq
    include SentryLogging

    def rescue_file_not_found(power_of_attorney)
      power_of_attorney.update(
        status: ClaimsApi::PowerOfAttorney::ERRORED,
        vbms_error_message: 'File could not be retrieved from AWS'
      )
    end

    def rescue_vbms_error(power_of_attorney)
      power_of_attorney.vbms_upload_failure_count = power_of_attorney.vbms_upload_failure_count + 1
      power_of_attorney.vbms_error_message = 'An unknown error has occurred when uploading document'
      if power_of_attorney.vbms_upload_failure_count < 5
        self.class.perform_in(30.minutes, power_of_attorney.id)
      else
        power_of_attorney.status = 'failed'
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

    def upload_to_vbms(power_of_attorney, path)
      uploader = VBMSUploader.new(
        filepath: path,
        file_number: power_of_attorney.auth_headers['va_eauth_pnid'],
        doc_type: '295'
      )
      upload_response = uploader.upload!
      power_of_attorney.update(
        status: ClaimsApi::PowerOfAttorney::UPLOADED,
        vbms_new_document_version_ref_id: upload_response[:vbms_new_document_version_ref_id],
        vbms_document_series_ref_id: upload_response[:vbms_document_series_ref_id]
      )
    end
  end
end
