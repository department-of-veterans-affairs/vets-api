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
      lighthouse_service = SimpleFormsApiSubmission::Service.new
      uuid_and_location = get_upload_location_and_uuid(lighthouse_service, form)
      form_submission = FormSubmission.create(
        form_type: params[:form_number],
        benefits_intake_uuid: uuid_and_location[:uuid],
        form_data: params.to_json,
        user_account: @current_user&.user_account
      )
      FormSubmissionAttempt.create(form_submission:)

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
      SimpleFormsApi::PdfStamper.new('tmp/vba_40_10007-tmp.pdf', form).stamp_uuid(uuid)

      { uuid:, location: upload_location.dig('data', 'attributes', 'location') }
    end
  end
end
