# frozen_string_literal: true

require 'sidekiq'
require 'claims_api/vbms_uploader'

module ClaimsApi
  class VbmsUploadJob
    include Sidekiq::Worker

    def perform(power_of_attorney_id)
      power_of_attorney = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      uploader = ClaimsApi::PowerOfAttorneyUploader.new(power_of_attorney_id)
      uploader.retrieve_from_store!(power_of_attorney.file_data['filename'])
      file_path = fetch_file_path(uploader)
      uploader = ClaimsApi::VbmsUploader.new(
        filepath: file_path,
        file_number: power_of_attorney.auth_headers['va_eauth_pnid'],
        doc_type: '295'
      )
      upload_response = uploader.upload!
      power_of_attorney.update(
        status: 'uploaded',
        vbms_new_document_version_ref_id: upload_response[:vbms_new_document_version_ref_id],
        vbms_document_series_ref_id: upload_response[:vbms_document_series_ref_id]
      )
    rescue VBMS::Unknown
      rescue_vbms_error(power_of_attorney)
    rescue Errno::ENOENT
      rescue_file_not_found(power_of_attorney)
    end

    def fetch_file_path(uploader)
      if Settings.evss.s3.uploads_enabled
        temp = URI.parse(uploader.file.url).open
        temp.path
      else
        uploader.file.file
      end
    end

    def rescue_file_not_found(power_of_attorney)
      power_of_attorney.update(
        status: 'failed',
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
  end
end
