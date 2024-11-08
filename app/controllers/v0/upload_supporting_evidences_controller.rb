# frozen_string_literal: true

require 'logging/third_party_transaction'

module V0
  class UploadSupportingEvidencesController < ApplicationController
    include FormAttachmentCreate
    extend Logging::ThirdPartyTransaction::MethodWrapper
    service_tag 'disability-application'

    FORM_ATTACHMENT_MODEL = SupportingEvidenceAttachment

    wrap_with_logging(
      :save_attachment_to_cloud!,
      additional_class_logs: {
        form: '526ez supporting evidence attachment',
        action: "upload: #{FORM_ATTACHMENT_MODEL}",
        upstream: 'User provided file',
        downstream: "S3 bucket: #{Settings.claims_api.evss.s3.bucket}"
      },
      additional_instance_logs: {
        user_uuid: %i[current_user account_uuid]
      }
    )

    private

    def serializer_klass
      SupportingEvidenceAttachmentSerializer
    end
  end
end
