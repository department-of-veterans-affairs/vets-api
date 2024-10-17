# frozen_string_literal: true

class AppealSubmissionUpload < ApplicationRecord
  validates :decision_review_evidence_attachment_guid, :appeal_submission_id, presence: true

  belongs_to :appeal_submission
  has_one :decision_review_evidence_attachment,
          primary_key: 'decision_review_evidence_attachment_guid',
          foreign_key: 'guid',
          class_name: 'DecisionReviewEvidenceAttachment',
          inverse_of: :appeal_submission_upload, dependent: :nullify

  scope :failure_not_sent, -> { where(failure_notification_sent_at: nil).order(id: :asc) }

  def attachment_filename
    form_attachment = FormAttachment.find_by(guid: decision_review_evidence_attachment_guid)
    raise "FormAttachment guid='#{guid}' not found" if form_attachment.nil?

    JSON.parse(form_attachment.file_data)['filename'].gsub(/(?<=.{3})[^_-](?=.{6})/, '*')
  end
end
