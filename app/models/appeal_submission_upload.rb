# frozen_string_literal: true

class AppealSubmissionUpload < ApplicationRecord
  validates :decision_review_evidence_attachment_guid, :appeal_submission_id, presence: true
end
