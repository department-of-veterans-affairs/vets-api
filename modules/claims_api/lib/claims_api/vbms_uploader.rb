# frozen_string_literal: true

module ClaimsApi
  class VBMSUploader
    def initialize(filepath:, file_number:, doc_type:)
      @filepath = filepath
      @file_number = file_number
      @doc_type = doc_type
    end

    def upload!
      upload_token_response = fetch_upload_token(
        filepath: @filepath,
        file_number: @file_number
      )

      upload_response = upload_document(
        filepath: @filepath,
        upload_token: upload_token_response.upload_token
      )

      {
        vbms_new_document_version_ref_id: upload_response.upload_document_response[:@new_document_version_ref_id],
        vbms_document_series_ref_id: upload_response.upload_document_response[:@document_series_ref_id]
      }
    end

    def fetch_upload_token(filepath:, file_number:)
      content_hash = Digest::SHA1.hexdigest(File.read(filepath))
      filename = SecureRandom.uuid + File.basename(filepath)
      vbms_request = VBMS::Requests::InitializeUpload.new(
        content_hash:,
        filename:,
        file_number:,
        va_receive_date: Time.zone.now,
        doc_type: @doc_type,
        source: 'BVA',
        subject: @doc_type,
        new_mail: true
      )
      client.send_request(vbms_request)
    end

    def upload_document(filepath:, upload_token:)
      upload_request = VBMS::Requests::UploadDocument.new(
        upload_token:,
        filepath:
      )
      client.send_request(upload_request)
    end

    def client
      @client ||= VBMS::Client.from_env_vars(env_name: Settings.vbms.env)
    end
  end
end
