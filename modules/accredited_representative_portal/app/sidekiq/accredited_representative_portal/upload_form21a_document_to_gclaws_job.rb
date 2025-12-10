# frozen_string_literal: true

module AccreditedRepresentativePortal
  class UploadForm21aDocumentToGCLAWSJob
    include Sidekiq::Job

    # 3 total attempts: 1 initial + 2 retries
    sidekiq_options retry: 2

    sidekiq_retries_exhausted do |job, exception|
      form21a_attachment_guid = job['args'].first
      Rails.logger.error(
        'UploadForm21aDocumentToGclawsJob: All retries exhausted for Form21aAttachment ' \
        "guid=#{form21a_attachment_guid}. Error: #{exception.class} - #{exception.message}"
      )
    end

    # @param form21a_attachment_guid [String] GUID of the Form21aAttachment record
    # @param application_id [String] applicationId returned from GCLAWS form submission
    # @param document_type [Integer] GCLAWS document type code
    # @param original_file_name [String] Original filename to send to GCLAWS
    # @param content_type [String] MIME type of the file (e.g., "application/pdf")
    def perform(form21a_attachment_guid, application_id, document_type, original_file_name, content_type)
      @form21a_attachment_guid = form21a_attachment_guid
      @application_id = application_id
      @document_type = document_type
      @original_file_name = original_file_name
      @content_type = content_type

      Rails.logger.info(
        "UploadForm21aDocumentToGclawsJob: Starting upload for Form21aAttachment guid=#{form21a_attachment_guid} " \
        "to application_id=#{application_id}"
      )

      attachment = find_attachment
      return unless attachment

      file = retrieve_file(attachment)
      return unless file

      upload_to_gclaws(file)
      delete_attachment(attachment)
    end

    private

    attr_reader :form21a_attachment_guid, :application_id, :document_type, :original_file_name, :content_type

    def find_attachment
      attachment = Form21aAttachment.find_by(guid: form21a_attachment_guid)

      unless attachment
        Rails.logger.error(
          "UploadForm21aDocumentToGclawsJob: Form21aAttachment not found for guid=#{form21a_attachment_guid}"
        )
      end

      attachment
    end

    def retrieve_file(attachment)
      attachment.get_file
    rescue Aws::S3::Errors::ServiceError, IOError => e
      # rubocop:disable Layout/LineLength
      Rails.logger.error(
        "UploadForm21aDocumentToGclawsJob: Retryable error retrieving file from S3 for guid=#{form21a_attachment_guid}. " \
        "Error: #{e.class} - #{e.message}"
      )
      # rubocop:enable Layout/LineLength
      raise
    rescue => e
      # rubocop:disable Layout/LineLength
      Rails.logger.error(
        "UploadForm21aDocumentToGclawsJob: Non-retryable error retrieving file from S3 for guid=#{form21a_attachment_guid}. " \
        "Error: #{e.class} - #{e.message}"
      )
      # rubocop:enable Layout/LineLength
      # Do not re-raise to avoid pointless retries
      nil
    end

    def upload_to_gclaws(file)
      response = connection.post do |req|
        req.headers['x-api-key'] = api_key
        req.headers['Content-Type'] = 'application/json'
        req.body = build_request_body(file)
      end

      handle_response(response)
    end

    # TODO: Consider adding file size validation and logging. Large files are loaded entirely into
    # memory for base64 encoding. If GCLAWS has file size limits, we should validate before upload.
    #
    # TODO: Confirm this payload structure matches the GCLAWS Document API spec.
    # Current assumptions: JSON body with ApplicationId, DocumentType, FileType, OriginalFileName,
    # and FileDetails (base64-encoded file content).
    def build_request_body(file)
      {
        ApplicationId: application_id,
        DocumentType: document_type,
        FileType: file_type,
        OriginalFileName: original_file_name,
        FileDetails: Base64.strict_encode64(file.read)
      }.to_json
    end

    def file_type
      Form21aDocumentUploadConstants.file_type_for(content_type)
    end

    def handle_response(response)
      if response.success?
        Rails.logger.info(
          'UploadForm21aDocumentToGclawsJob: Successfully uploaded Form21aAttachment ' \
          "guid=#{form21a_attachment_guid} to GCLAWS application_id=#{application_id}"
        )
      else
        Rails.logger.error(
          "UploadForm21aDocumentToGclawsJob: GCLAWS API error for guid=#{form21a_attachment_guid}. " \
          "Status: #{response.status}, Body: #{response.body}"
        )
        raise "GCLAWS Document API returned #{response.status}: #{response.body}"
      end
    end

    def delete_attachment(attachment)
      attachment.destroy!
      Rails.logger.info(
        'UploadForm21aDocumentToGclawsJob: Deleted Form21aAttachment ' \
        "guid=#{form21a_attachment_guid} after successful upload"
      )
    rescue => e
      Rails.logger.error(
        "UploadForm21aDocumentToGclawsJob: Failed to delete Form21aAttachment guid=#{form21a_attachment_guid}. " \
        "Error: #{e.class} - #{e.message}"
      )
      # Don't re-raise - the upload succeeded, deletion failure shouldn't cause retry
    end

    def connection
      @connection ||= Faraday.new(url: document_upload_url) do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
      end
    end

    def document_upload_url
      Settings.ogc.form21a_service_url.document_upload_url
    end

    def api_key
      Settings.ogc.form21a_service_url.api_key
    end
  end
end
