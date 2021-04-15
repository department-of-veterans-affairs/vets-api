# frozen_string_literal: true

# Files uploaded as part of a Notice of Disagreement submission that will be sent to Lighthouse upon form submission.
# inherits from ApplicationRecord
class DecisionReviewEvidenceAttachment < FormAttachment
  ATTACHMENT_UPLOADER_CLASS = DecisionReviewEvidenceAttachmentUploader
end
