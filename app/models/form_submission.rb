# frozen_string_literal: true

class FormSubmission < ApplicationRecord
  has_kms_key
  has_encrypted :form_data, key: :kms_key, **lockbox_options

  has_many :form_submission_attempts, dependent: :destroy
  belongs_to :saved_claim, optional: true
  belongs_to :user_account, optional: true

  validates :form_type, presence: true

  class << self
    # rubocop:disable Metrics/MethodLength
    def with_latest_benefits_intake_uuid(user_account)
      # This query retrieves distinct form submissions for a given user account,
      # along with the latest benefits intake UUID for each form. If a form has any
      # submission attempts with a benefits_intake_uuid, it uses the latest attempt's UUID;
      # otherwise, it falls back to the form submission's original UUID.
      FormSubmission
        .select(
          'DISTINCT form_submissions.id,
          form_submissions.form_type,
          COALESCE(latest_attempts.benefits_intake_uuid, form_submissions.benefits_intake_uuid) AS benefits_intake_uuid,
          form_submissions.created_at'
        )
        .left_joins(:form_submission_attempts)
        .joins(
          'LEFT JOIN (
            SELECT fsa.form_submission_id, fsa.benefits_intake_uuid
            FROM form_submission_attempts fsa
            INNER JOIN (
              SELECT form_submission_id, MAX(created_at) AS latest_attempt
              FROM form_submission_attempts
              WHERE form_submission_attempts.benefits_intake_uuid IS NOT NULL
              GROUP BY form_submission_id
            ) latest_fsa ON fsa.form_submission_id = latest_fsa.form_submission_id
                          AND fsa.created_at = latest_fsa.latest_attempt
          ) latest_attempts ON form_submissions.id = latest_attempts.form_submission_id'
        )
        .where(user_account:)
    end
    # rubocop:enable Metrics/MethodLength

    def with_form_types(form_types)
      if form_types.present?
        where(form_type: form_types)
      else
        where.not(form_type: nil)
      end
    end
  end

  def latest_attempt
    form_submission_attempts.order(created_at: :asc).last
  end

  def latest_pending_attempt
    form_submission_attempts.where(aasm_state: 'pending').order(created_at: :asc).last
  end

  def non_failure_attempt
    form_submission_attempts.where(aasm_state: %w[pending success]).first
  end
end
