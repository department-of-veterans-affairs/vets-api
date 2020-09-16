# frozen_string_literal: true

# Files uploaded as part of a form526 submission that will be sent to EVSS upon form submission.
class SupportingEvidenceAttachment < FormAttachment
  ATTACHMENT_UPLOADER_CLASS = SupportingEvidenceAttachmentUploader
end
