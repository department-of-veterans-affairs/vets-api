# frozen_string_literal: true

# require 'simple_forms_api_submission/service'

module SimpleFormsApi
  class PdfUploader
    attr_reader :file_path, :metadata, :form

    def initialize(file_path, metadata, form)
      @file_path = file_path
      @metadata = metadata
      @form = form
    end

    def upload_to_benefits_intake(params)
      lighthouse_service = SimpleFormsApiSubmission::Service.new
      uuid_and_location = get_upload_location_and_uuid(lighthouse_service, form)
      create_form_submission_attempt(params, uuid_and_location)

      # Validate document before uploading
      validate_pdf_document(file_path)

      Datadog::Tracing.active_trace&.set_tag('uuid', uuid_and_location[:uuid])
      Rails.logger.info(
        'Simple forms api - preparing to upload PDF to benefits intake',
        { location: uuid_and_location[:location], uuid: uuid_and_location[:uuid] }
      )
      response = lighthouse_service.upload_doc(
        upload_url: uuid_and_location[:location],
        file: file_path,
        metadata: metadata.to_json
      )

      [response.status, uuid_and_location[:uuid]]
    end

    private

    def get_upload_location_and_uuid(lighthouse_service, form)
      upload_location = lighthouse_service.get_upload_location.body

      # Stamp uuid on 40-10007
      uuid = upload_location.dig('data', 'id')
      SimpleFormsApi::PdfStamper.new(stamped_template_path: file_path, form:).stamp_uuid(uuid)

      { uuid:, location: upload_location.dig('data', 'attributes', 'location') }
    end

    def create_form_submission_attempt(params, uuid_and_location)
      FormSubmissionAttempt.transaction do
        form_submission = FormSubmission.create(
          form_type: params[:form_number],
          form_data: params.to_json,
          user_account: @current_user&.user_account
        )
        FormSubmissionAttempt.create(form_submission:, benefits_intake_uuid: uuid_and_location[:uuid])
      end
    end

    def validate_pdf_document(file_path)
      extension = File.extname(file_path)
      allowed_types = PersistentAttachment::ALLOWED_DOCUMENT_TYPES

      if allowed_types.exclude?(extension)
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: I18n.t('errors.messages.extension_allowlist_error', extension: extension, allowed_types: allowed_types),
          source: 'SimpleFormsApi::PdfUploader.validate_pdf_document'
        )
      elsif File.size(file_path) < PersistentAttachment::MINIMUM_FILE_SIZE
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: 'File size must not be less than 1.0 KB',
          source: 'SimpleFormsApi::PdfUploader.validate_pdf_document'
        )
      end

      # Validate with Benefits Intake API
      document = PDFUtilities::DatestampPdf.new(file_path).run(text: 'VA.GOV', x: 5, y: 5)
      intake_service = BenefitsIntake::Service.new
      intake_service.valid_document?(document: document)
    rescue BenefitsIntake::Service::InvalidDocumentError => e
      raise Common::Exceptions::UnprocessableEntity.new(
        detail: e.message,
        source: 'SimpleFormsApi::PdfUploader.validate_pdf_document'
      )
    end
  end
end
