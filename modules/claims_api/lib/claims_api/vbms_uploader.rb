# frozen_string_literal: true

require 'vets/shared_logging'

module ClaimsApi
  class VBMSUploader
    include Vets::SharedLogging

    def initialize(filepath:, file_number:, doc_type:)
      @filepath = filepath
      @file_number = file_number
      @doc_type = doc_type
    end

    # rubocop:disable Metrics/MethodLength
    def upload!
      upload_token_response = fetch_upload_token(
        filepath: @filepath,
        file_number: @file_number
      )

      # TODO: remove temp logging for troubleshooting related to VRE claim upload to VBMS
      file_exists = File.exist?(@filepath)
      if !file_exists && caller.first.match(/veteran_readiness_employment_claim.rb/)
        log_message_to_sentry(
          "VBMSUploader#upload! file exists?: #{file_exists}",
          :warn,
          {},
          { team: 'vfs-ebenefits' }
        )
      end

      upload_response = upload_document(
        filepath: @filepath,
        upload_token: upload_token_response.upload_token
      )

      # TODO: remove temp logging for troubleshooting related to VRE claim upload to VBMS
      file_exists = File.exist?(@filepath)
      if !file_exists && caller.first.match(/veteran_readiness_employment_claim.rb/)
        log_message_to_sentry(
          "VBMSUploader#upload! upload_response: #{upload_response}",
          :warn,
          {},
          { team: 'vfs-ebenefits' }
        )
      end
      {
        vbms_new_document_version_ref_id: upload_response.upload_document_response[:@new_document_version_ref_id],
        vbms_document_series_ref_id: upload_response.upload_document_response[:@document_series_ref_id]
      }
    end
    # rubocop:enable Metrics/MethodLength

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
