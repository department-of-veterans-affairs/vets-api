# frozen_string_literal: true

module SimpleFormsApi
  class ScannedFormUploadService
    attr_reader :params, :current_user, :lighthouse_service

    def initialize(params:, current_user:, lighthouse_service:)
      @params = params
      @current_user = current_user
      @lighthouse_service = lighthouse_service
    end

    def upload_with_supporting_documents
      main_attachment = find_main_attachment
      main_file_path = stamp_main_file(main_attachment)
      supporting_attachments = find_supporting_attachments
      metadata = build_metadata
      status, confirmation_number = upload_to_lighthouse(main_file_path, supporting_attachments, metadata)

      log_upload_result(main_file_path, status, confirmation_number)

      [status, confirmation_number]
    end

    private

    def find_main_attachment
      PersistentAttachment.find_by!(guid: params[:confirmation_code])
    rescue ActiveRecord::RecordNotFound
      raise Common::Exceptions::RecordNotFound.new(
        params[:confirmation_code],
        detail: 'Attachment not found'
      )
    end

    def find_main_attachment_path(attachment)
      attachment.to_pdf.to_s
    end

    def stamp_main_file(attachment)
      file_path = find_main_attachment_path(attachment)
      stamper = SimpleFormsApi::PdfStamper.new(
        stamped_template_path: file_path,
        current_loa: current_user.loa[:current],
        timestamp: Time.current
      )
      stamper.stamp_pdf
      file_path
    end

    def find_supporting_attachments
      return [] if params[:supporting_documents].blank?

      confirmation_codes = params[:supporting_documents].map { |doc| doc[:confirmation_code] }
      PersistentAttachment.where(guid: confirmation_codes)
    end

    def build_metadata
      raw_metadata = {
        'veteranFirstName' => params.dig(:form_data, :full_name, :first),
        'veteranLastName' => params.dig(:form_data, :full_name, :last),
        'fileNumber' => params.dig(:form_data, :id_number, :ssn) ||
                        params.dig(:form_data, :id_number, :va_file_number),
        'zipCode' => params.dig(:form_data, :postal_code),
        'source' => 'VA Platform Digital Forms',
        'docType' => params[:form_number],
        'businessLine' => 'CMP'
      }
      SimpleFormsApiSubmission::MetadataValidator.validate(raw_metadata)
    end

    def upload_to_lighthouse(main_file_path, supporting_attachments, metadata)
      location, uuid = lighthouse_service.request_upload
      create_form_submission_attempt(uuid)
      log_upload_preparation(location, uuid)

      attachment_paths = supporting_attachments.map { |attachment| attachment.to_pdf.to_s }

      response = lighthouse_service.perform_upload(
        metadata: metadata.to_json,
        document: main_file_path,
        upload_url: location,
        attachments: attachment_paths
      )

      [response.status, uuid]
    end

    def create_form_submission_attempt(uuid)
      FormSubmissionAttempt.transaction do
        form_submission = create_form_submission
        FormSubmissionAttempt.create(form_submission:, benefits_intake_uuid: uuid)
      end
    end

    def create_form_submission
      FormSubmission.create(
        form_type: params[:form_number],
        form_data: params[:form_data].to_json,
        user_account: current_user&.user_account
      )
    end

    def log_upload_preparation(location, uuid)
      Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
      Rails.logger.info('Simple forms api - preparing to upload scanned PDF to benefits intake',
                        { location:, uuid: })
    end

    def log_upload_result(file_path, status, confirmation_number)
      file_size = File.size(file_path).to_f / (2**20)
      Rails.logger.info(
        'Simple forms api - scanned form uploaded',
        { form_number: params[:form_number], status:, confirmation_number:,
          file_size: }
      )
    end
  end
end
