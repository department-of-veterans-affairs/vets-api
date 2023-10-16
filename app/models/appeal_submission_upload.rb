# frozen_string_literal: true

class AppealSubmissionUpload < ApplicationRecord
  validates :decision_review_evidence_attachment_guid, :appeal_submission_id, presence: true

  belongs_to :appeal_submission
  has_one :decision_review_evidence_attachment,
          primary_key: 'decision_review_evidence_attachment_guid',
          foreign_key: 'guid',
          class_name: 'DecisionReviewEvidenceAttachment',
          inverse_of: :appeal_submission_upload, dependent: :nullify
end
