# frozen_string_literal: true

module AccreditedRepresentativePortal
  # Service to orchestrate uploading Form 21a document attachments to GCLAWS
  # after the main form has been successfully submitted.
  class Form21aDocumentUploadService
    # Enqueues background jobs to upload all documents associated with a Form 21a submission
    #
    # @param in_progress_form [InProgressForm] The in-progress form containing document metadata
    # @param application_id [String] The applicationId returned from GCLAWS form submission
    # @return [Integer] The number of upload jobs enqueued
    def self.enqueue_uploads(in_progress_form:, application_id:)
      new(in_progress_form:, application_id:).enqueue_uploads
    end

    def initialize(in_progress_form:, application_id:)
      @in_progress_form = in_progress_form
      @application_id = application_id
    end

    def enqueue_uploads
      documents = extract_all_documents
      return 0 if documents.empty?

      Rails.logger.info(
        "Form21aDocumentUploadService: Enqueuing #{documents.size} document uploads " \
        "for application_id=#{application_id}"
      )

      documents.each do |document|
        enqueue_upload_job(document)
      end

      documents.size
    end

    private

    attr_reader :in_progress_form, :application_id

    def extract_all_documents
      form_data = parse_form_data
      documents = []

      Form21aDocumentUploadConstants::DOCUMENT_TYPES.each_key do |documents_key|
        next unless form_data[documents_key].is_a?(Array)

        document_type = Form21aDocumentUploadConstants.document_type_for(documents_key)

        form_data[documents_key].each do |doc|
          documents << {
            confirmation_code: doc['confirmationCode'],
            original_file_name: doc['name'],
            content_type: doc['type'],
            document_type:
          }
        end
      end

      documents
    end

    def parse_form_data
      return {} if in_progress_form.form_data.blank?

      JSON.parse(in_progress_form.form_data)
    rescue JSON::ParserError => e
      Rails.logger.error(
        "Form21aDocumentUploadService: Failed to parse form_data for in_progress_form_id=#{in_progress_form.id}. " \
        "Error: #{e.message}"
      )
      {}
    end

    def enqueue_upload_job(document)
      UploadForm21aDocumentToGCLAWSJob.perform_async(
        document[:confirmation_code],
        application_id,
        document[:document_type],
        document[:original_file_name],
        document[:content_type]
      )

      Rails.logger.info(
        'Form21aDocumentUploadService: Enqueued upload job for Form21aAttachment ' \
        "guid=#{document[:confirmation_code]} document_type=#{document[:document_type]}"
      )
    end
  end
end
