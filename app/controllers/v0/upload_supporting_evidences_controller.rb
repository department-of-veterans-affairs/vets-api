# frozen_string_literal: true

require 'logging/third_party_transaction'

module V0
  class UploadSupportingEvidencesController < ApplicationController
    extend Logging::ThirdPartyTransaction::MethodWrapper

    VALID_FILE_CLASSES = [ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile].freeze

    wrap_with_logging(
      :save_attachment_to_cloud!,
      additional_class_logs: {
        form: '526ez supporting evidence attachment',
        action: 'Uploaded user-provided attachment to S3',
        upstream: 'User provided file',
        downstream: "S3 bucket: #{Settings.evss.s3.bucket}"
      },
      additional_instance_logs: {
        user_uuid: %i[current_user account_uuid]
      }
    )

    def create
      validate_file_upload_class!
      save_attachment_to_cloud!
      save_attachment_to_db!

      render(json: form_attachment)
    end

    private

    def validate_file_upload_class!
      file_class = attachment_params[:file_data].class

      unless VALID_FILE_CLASSES.include?(file_class)
        raise Common::Exceptions::InvalidFieldValue.new('file_data', file_class)
      end
    end

    def save_attachment_to_cloud!
      form_attachment.set_file_data!(attachment_params[:file_data], attachment_params[:password])
    end

    def save_attachment_to_db!
      form_attachment.save!
    end

    def form_attachment
      @form_attachment ||= form_attachment_model.new
    end

    def form_attachment_model
      if Flipper.enabled?(:disability_compensation_lighthouse_document_service_provider)
        LighthouseSupportingEvidenceAttachment
      else
        SupportingEvidenceAttachment
      end
    end

    def attachment_params
      params.require(:supporting_evidence_attachment).permit(:file_data, :password)
    end
  end
end
