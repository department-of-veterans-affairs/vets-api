# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class VbmsUploader
    include Sidekiq::Worker

    def perform(power_of_attorney_id)
      power_of_attorney = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      uploader = ClaimsApi::PowerOfAttorneyUploader.new(power_of_attorney_id)
      uploader.retrieve_from_store!(power_of_attorney.file_data[:filename])
      filepath = fetch_file_path(uploader, power_of_attorney.file_data['filename'])

      upload_token_response = fetch_upload_token(
        filepath: filepath,
        file_number: power_of_attorney.auth_headers['va_eauth_pnid']
      )
      upload_response = upload_document(filepath: filepath, upload_token: upload_token_response.upload_token)
      power_of_attorney.update(
        status: 'uploaded',
        vbms_new_document_version_ref_id: upload_response.upload_document_response[:@new_document_version_ref_id],
        vbms_document_series_ref_id: upload_response.upload_document_response[:@document_series_ref_id]
      )
    rescue VBMS::Unknown
      rescue_vbms_error(power_of_attorney)
    rescue Errno::ENOENT
      rescue_file_not_found(power_of_attorney)
    end

    def fetch_file_path(uploader, filename)
      if Settings.evss.s3.uploads_enabled
        temp = URI.parse(uploader.file.url).open
        temp.path
      else
        "#{uploader.file.file}/#{filename}"
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

    def client
      @client ||= VBMS::Client.from_env_vars
    end

    def fetch_upload_token(filepath:, file_number:)
      content_hash = Digest::SHA1.hexdigest(File.read(filepath))
      filename = SecureRandom.uuid + File.basename(filepath)

      vbms_request = VBMS::Requests::InitializeUpload.new(
        content_hash: content_hash,
        filename: filename,
        file_number: file_number,
        va_receive_date: Time.zone.now,
        doc_type: '295',
        source: 'BVA',
        subject: '295',
        new_mail: true
      )
      client.send_request(vbms_request)
    end

    def upload_document(filepath:, upload_token:)
      upload_request = VBMS::Requests::UploadDocument.new(
        upload_token: upload_token,
        filepath: filepath
      )
      client.send_request(upload_request)
    end
  end
end
