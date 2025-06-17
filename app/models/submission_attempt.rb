# frozen_string_literal: true

require 'json_marshal/marshaller'

class SubmissionAttempt < ApplicationRecord
  self.abstract_class = true

  after_create :update_submission_status
  before_update :update_submission_status

  validates :submission, presence: true

  private

  def update_submission_status
    submission.update(latest_status: status) if status_changed? || id_previously_changed?
  end

  def status_change_hash
    {
      submission_id: submission.id,
      claim_id: submission.saved_claim_id,
      form_type: submission.form_id,
      from_state: previous_changes[:status]&.first,
      to_state: status,
      benefits_intake_uuid:
    }
  end
end
