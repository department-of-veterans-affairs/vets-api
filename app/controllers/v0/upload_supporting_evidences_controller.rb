# frozen_string_literal: true

require 'logging/third_party_transaction'

module V0
  class UploadSupportingEvidencesController < ApplicationController
    include FormAttachmentCreate
    extend Logging::ThirdPartyTransaction::MethodWrapper

    FORM_ATTACHMENT_MODEL = SupportingEvidenceAttachment

    wrap_with_logging :save_attachment_to_cloud!, additional_logs: {
      form: '526ez supporting evidence attachment',
      action: "upload: #{FORM_ATTACHMENT_MODEL}",
      upstream: 'User provided file',
      downstream: "S3 bucket: #{Settings.evss.s3.bucket}"
    }
  end
end
