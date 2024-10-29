# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'simple_forms_api_submission/metadata_validator'

module SimpleFormsApi
  module V1
    class ScannedFormUploadsController < ApplicationController
      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])
        render json: upload_response
      end

      def upload_scanned_form
        attachment = PersistentAttachments::VAForm.new
        attachment.form_id = params['form_id']
        attachment.file = params['file']
        raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

        attachment.save
        render json: PersistentAttachmentVAFormSerializer.new(attachment)
      end

      private

      def lighthouse_service
        @lighthouse_service ||= BenefitsIntake::Service.new
      end

      def upload_response
        file_path = find_attachment_path(params[:confirmation_code])
        metadata = validated_metadata
        status, confirmation_number = upload_pdf(file_path, metadata)

        { confirmation_number:, status: }
      end

      def find_attachment_path(confirmation_code)
        PersistentAttachment.find_by(guid: confirmation_code).to_pdf.to_s
      end

      def validated_metadata
        raw_metadata = {
          'veteranFirstName' => @current_user.first_name,
          'veteranLastName' => @current_user.last_name,
          'fileNumber' => params.dig(:options, :ssn) ||
                          params.dig(:options, :va_file_number) ||
                          @current_user.ssn,
          'zipCode' => params.dig(:options, :zip_code) ||
                       @current_user.address[:postal_code],
          'source' => 'VA Platform Digital Forms',
          'docType' => params[:form_number],
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
          form_submission = create_form_submission(uuid)
          FormSubmissionAttempt.create(form_submission:, benefits_intake_uuid: uuid)
        end
      end

      def create_form_submission(uuid)
        FormSubmission.create(
          form_type: params[:form_number],
          benefits_intake_uuid: uuid,
          user_account: @current_user&.user_account
        )
      end

      def log_upload_details(location, uuid)
        Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
        Rails.logger.info('Simple forms api - preparing to upload scanned PDF to benefits intake', { location:, uuid: })
      end

      def perform_pdf_upload(location, file_path, metadata)
        lighthouse_service.perform_upload(
          metadata: metadata.to_json,
          document: file_path,
          upload_url: location
        )
      end
    end
  end
end
