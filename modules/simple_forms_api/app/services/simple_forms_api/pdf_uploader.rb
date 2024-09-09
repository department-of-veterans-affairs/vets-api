# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'

module SimpleFormsApi
  class PdfUploader
    attr_reader :file_path, :metadata, :form, :form_id, :params, :current_user

    def initialize(settings)
      @file_path = settings[:file_path]
      @metadata = settings[:metadata]
      @form = settings[:form]
      @form_id = settings[:form_id]
      @params = settings[:params]
      @current_user = settings[:current_user]
    end

    def upload_to_benefits_intake
      location, uuid = prepare_for_upload
      log_upload_details(location, uuid)
      response = perform_pdf_upload(location, file_path)

      [response.status, uuid]
    end

    private

    def lighthouse_service
      @lighthouse_service ||= BenefitsIntake::Service.new
    end

    def prepare_for_upload
      Rails.logger.info('Simple forms api - preparing to request upload location from Lighthouse', form_id:)
      location, uuid = lighthouse_service.request_upload
      stamp_pdf_with_uuid(uuid)
      create_form_submission_attempt(uuid)

      [location, uuid]
    end

    def stamp_pdf_with_uuid(uuid)
      # Stamp uuid on 40-10007
      pdf_stamper = SimpleFormsApi::PdfStamper.new(stamped_template_path: file_path, form:)
      pdf_stamper.stamp_uuid(uuid)
    end

    def create_form_submission_attempt(uuid)
      form_submission = create_form_submission(uuid)
      FormSubmissionAttempt.create(form_submission:)
    end

    def create_form_submission(uuid)
      FormSubmission.create(
        form_type: form_id,
        benefits_intake_uuid: uuid,
        form_data: params.to_json,
        user_account: current_user&.user_account
      )
    end

    def log_upload_details(location, uuid)
      Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
      Rails.logger.info('Simple forms api - preparing to upload PDF to benefits intake', { location:, uuid: })
    end

    def perform_pdf_upload(location, file_path)
      lighthouse_service.perform_upload(
        metadata: metadata.to_json,
        document: file_path,
        upload_url: location
      )
    end
  end
end
