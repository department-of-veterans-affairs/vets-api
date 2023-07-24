# frozen_string_literal: true

module V0
  class UploadSupportingEvidencesController < ApplicationController
    include FormAttachmentCreate
    extend ThirdPartyTransactionLogging::MethodWrapper

    FORM_ATTACHMENT_MODEL = SupportingEvidenceAttachment

    wrap_with_logging :save_attachment_to_cloud!, additional_logs: {
      form: '526ez supporting evidence attachment',
      action: "upload: #{FORM_ATTACHMENT_MODEL}",
      upstream: "S3 bucket: #{Settings.evss.s3.bucket}"
    }
  end
end
