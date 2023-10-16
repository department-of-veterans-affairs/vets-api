# frozen_string_literal: true

require 'decision_review/utilities/pdf_validation/service'

# Files uploaded as part of a Notice of Disagreement submission that will be sent to Lighthouse upon form submission.
# inherits from ApplicationRecord
class DecisionReviewEvidenceAttachment < FormAttachment
  ATTACHMENT_UPLOADER_CLASS = DecisionReviewEvidenceAttachmentUploader

  validate :validate_pdf

  def validate_pdf
    validation_enabled = Settings.decision_review.pdf_validation.enabled
    validation_enabled ? decision_review_pdf_service.validate_pdf_with_lighthouse(get_file) : true
  end

  private

  def decision_review_pdf_service
    DecisionReview::PdfValidation::Service.new
  end
end
