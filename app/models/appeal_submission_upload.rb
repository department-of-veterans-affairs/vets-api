# frozen_string_literal: true

class AppealSubmissionUpload < ApplicationRecord
  validates :decision_review_evidence_attachment_guid, presence: true

  belongs_to :appeal_submission
  has_one :decision_review_evidence_attachment,
          primary_key: 'decision_review_evidence_attachment_guid',
          foreign_key: 'guid',
          class_name: 'DecisionReviewEvidenceAttachment',
          inverse_of: :appeal_submission_upload, dependent: :nullify

  scope :failure_not_sent, -> { where(failure_notification_sent_at: nil).order(id: :asc) }

  # Matches all characters except first 3 characters, last 6 characters (2 + .pdf extension), underscores, and hyphens
  MASK_REGEX = /(?<=.{3})[^_-](?=.{6})/

  def masked_attachment_filename
    filename = JSON.parse(decision_review_evidence_attachment&.file_data || '{}')['filename']
    raise 'Filename for AppealSubmissionUpload not found' if filename.nil?

    filename.gsub(MASK_REGEX, 'X')
  end
end
