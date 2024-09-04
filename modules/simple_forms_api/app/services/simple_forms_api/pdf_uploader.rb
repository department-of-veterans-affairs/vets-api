# frozen_string_literal: true

require 'simple_forms_api_submission/service'

module SimpleFormsApi
  class PdfUploader
    attr_reader :file_path, :metadata, :form

    def initialize(file_path, metadata, form)
      @file_path = file_path
      @metadata = metadata
      @form = form
    end

    def upload_to_benefits_intake(params)
      upload_data = fetch_upload_data
      form_submission = create_form_submission(params, upload_data[:uuid])

      create_form_submission_attempt(form_submission)
      log_pre_upload_info(upload_data[:uuid])

      response = upload_document(upload_data[:location])

      [response.status, upload_data[:uuid]]
    end

    private

    def lighthouse_service
      @lighthouse_service ||= SimpleFormsApiSubmission::Service.new
    end

    def fetch_upload_data
      upload_location = lighthouse_service.get_upload_location.body
      uuid = upload_location.dig('data', 'id')
      location = upload_location.dig('data', 'attributes', 'location')
      stamp_pdf_with_uuid(uuid)

      { uuid:, location: }
    end

    def stamp_pdf_with_uuid(uuid)
      # Stamp uuid on 40-10007
      PdfStamper.new(stamped_template_path: 'tmp/vba_40_10007-tmp.pdf', form: @form).stamp_uuid(uuid)
    end

    def create_form_submission(params, uuid)
      FormSubmission.create(
        form_type: params[:form_number],
        benefits_intake_uuid: uuid,
        form_data: params.to_json,
        user_account: @current_user&.user_account
      )
    end

    def create_form_submission_attempt(form_submission)
      FormSubmissionAttempt.create(form_submission:)
    end

    def log_pre_upload_info(uuid)
      Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
      Rails.logger.info('Simple forms api - preparing to upload PDF to benefits intake', uuid:)
    end

    def upload_document(location)
      lighthouse_service.upload_doc(
        upload_url: location,
        file: file_path,
        metadata: metadata.to_json
      )
    end
  end
end
