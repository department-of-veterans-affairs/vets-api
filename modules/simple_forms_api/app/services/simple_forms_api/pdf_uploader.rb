# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'

module SimpleFormsApi
  class PdfUploader
    attr_reader :file_path, :metadata, :form_id

    def initialize(file_path, metadata, form_id)
      @file_path = file_path
      @metadata = metadata
      @form_id = form_id
    end

    def upload_to_benefits_intake(params)
      lighthouse_service = BenefitsIntake::Service.new
      location, uuid = lighthouse_service.request_upload
      SimpleFormsApi::PdfStamper.stamp4010007_uuid(uuid) if form_id == 'vba_40_10007'
      create_form_submission_attempt(params, uuid)
      Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
      Rails.logger.info(
        'Simple forms api - preparing to upload PDF to benefits intake',
        { location:, uuid: }
      )
      response = lighthouse_service.perform_upload(
        metadata: metadata.to_json,
        document: file_path,
        upload_url: location
      )

      [response.status, uuid]
    end

    private

    def create_form_submission_attempt(params, uuid)
      form_submission = FormSubmission.create(
        form_type: params[:form_number],
        benefits_intake_uuid: uuid,
        form_data: params.to_json,
        user_account: @current_user&.user_account
      )
      FormSubmissionAttempt.create(form_submission:)
    end
  end
end
