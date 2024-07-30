# frozen_string_literal: true

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
        SimpleFormsApi::PdfUploader.new(file_path, metadata, params[:form_number]).upload_to_benefits_intake(params)
      end
    end
  end
end
