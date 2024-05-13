# frozen_string_literal: true

class DecisionReviewEvidenceAttachmentValidation < ApplicationRecord
  has_kms_key
  has_encrypted :password, key: :kms_key, **lockbox_options

  validates :decision_review_evidence_attachment_guid, presence: true
end
