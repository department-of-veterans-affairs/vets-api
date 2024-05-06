# frozen_string_literal: true

module SimpleFormsApi
  module V1
    class ScannedFormUploadsController < ApplicationController
      # skip_before_action :authenticate

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])

        confirmation_code = params[:confirmation_code]
        attachment = PersistentAttachment.find_by(guid: confirmation_code)
        file_path = attachment.to_pdf.to_s
        raw_metadata = {
          'veteranFirstName' => @current_user.first_name,
          'veteranLastName' => @current_user.last_name,
          'fileNumber' => @current_user.ssn,
          'zipCode' => @current_user.address[:postal_code],
          'source' => 'VA Platform Digital Forms',
          'docType' => params[:form_number],
          'businessLine' => 'CMP'
        }
        metadata = SimpleFormsApiSubmission::MetadataValidator.validate(raw_metadata)

        status, confirmation_number = SimpleFormsApi::PdfUploader.new(
          file_path,
          metadata,
          params[:form_number]
        ).upload_to_benefits_intake(params)

        render json: { confirmation_number:, status: }
      end

      def upload_scanned_form
        attachment = PersistentAttachments::MilitaryRecords.new(form_id: params['formId'])
        attachment.file = params['file']
        raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

        attachment.save
        render json: attachment
      end
    end
  end
end
