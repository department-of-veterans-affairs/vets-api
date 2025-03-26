# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'simple_forms_api_submission/metadata_validator'

module AccreditedRepresentativePortal
  module V0
    class RepresentativeFormUploadController < ApplicationController
      skip_after_action :verify_pundit_authorization

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', form_data[:formNumber])
        check_for_changes
        status, confirmation_number = upload_response
        render json: { status:, confirmation_number: }
      end

      def upload_scanned_form
        attachment = PersistentAttachments::VAForm.new
        attachment.form_id = params['form_id']
        attachment.file = params['file']
        raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

        attachment.save
        render json: RepresentativeAttachmentFormSerializer.new(attachment)
      end

      private

      def lighthouse_service
        @lighthouse_service ||= BenefitsIntake::Service.new
      end

      def upload_response
        file_path = find_attachment_path(params[:confirmationCode])
        stamper = SimpleFormsApi::PdfStamper.new(
          stamped_template_path: file_path,
          current_loa: @current_user.loa[:current],
          timestamp: Time.current
        )
        stamper.stamp_pdf
        metadata = validated_metadata
        status, confirmation_number = upload_pdf(file_path, metadata)
        file_size = File.size(file_path).to_f / (2**20)

        Rails.logger.info(
          'Accredited Rep Form Upload - scanned form uploaded',
          { form_number: form_data[:formNumber], status:, confirmation_number:, file_size: }
        )
        [status, confirmation_number]
      end

      def find_attachment_path(confirmation_code)
        PersistentAttachment.find_by(guid: confirmation_code).to_pdf.to_s
      end

      def validated_metadata
        raw_metadata = {
          'veteranFirstName' => form_params.dig('formData', 'veteranFullName', 'first'),
          'veteranLastName' => form_params.dig('formData', 'veteranFullName', 'last'),
          'fileNumber' => form_params.dig('formData', 'veteranSsn'),
          'zipCode' => form_params.dig(:formData, :postalCode),
          'source' => 'VA Platform Digital Forms',
          'docType' => form_data[:formNumber],
          'businessLine' => 'CMP'
        }
        SimpleFormsApiSubmission::MetadataValidator.validate(raw_metadata)
      end

      def upload_pdf(file_path, metadata)
        location, uuid = prepare_for_upload
        log_upload_details(location, uuid)
        response = perform_pdf_upload(location, file_path, metadata)
        [response.status, uuid]
      end

      def prepare_for_upload
        location, uuid = lighthouse_service.request_upload
        create_form_submission_attempt(uuid)

        [location, uuid]
      end

      def create_form_submission_attempt(uuid)
        FormSubmissionAttempt.transaction do
          form_submission = create_form_submission
          FormSubmissionAttempt.create(form_submission:, benefits_intake_uuid: uuid)
        end
      end

      def create_form_submission
        FormSubmission.create(
          form_type: form_data[:formNumber],
          form_data: form_data.to_json,
          user_account: @current_user&.user_account
        )
      end

      def log_upload_details(location, uuid)
        Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
        Rails.logger.info('Accredited Rep Form Upload  - preparing to upload scanned PDF to benefits intake',
                          { location:, uuid: })
      end

      def perform_pdf_upload(location, file_path, metadata)
        lighthouse_service.perform_upload(
          metadata: metadata.to_json,
          document: file_path,
          upload_url: location
        )
      end

      def check_for_changes
        in_progress_form = InProgressForm.form_for_user(form_data[:formNumber], @current_user)
        if in_progress_form

          prefill_data_service = SimpleFormsApi::PrefillDataService.new(prefill_data: in_progress_form.form_data,
                                                                        form_data:,
                                                                        form_id: form_data[:formNumber])
          prefill_data_service.check_for_changes
        end
      end

      def form_params
        params.require(:representative_form_upload).permit(
          :confirmationCode,
          :location,
          :formNumber,
          :formName,
          formData: [
            :veteranSsn,
            :formNumber,
            :postalCode,
            :veteranDateOfBirth,
            :email,
            :postal_code,
            :claimantDateOfBirth,
            { claimantFullName: %i[first last] },
            :claimantSsn,
            { veteranFullName: %i[first last] }
          ]
        )
      end

      def form_data
        form_params['formData']
      end
    end
  end
end
