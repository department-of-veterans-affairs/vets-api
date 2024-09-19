# frozen_string_literal: true

class FormSubmission < ApplicationRecord
  has_kms_key
  has_encrypted :form_data, key: :kms_key, **lockbox_options

  has_many :form_submission_attempts, dependent: :destroy
  belongs_to :saved_claim, optional: true
  belongs_to :user_account, optional: true

  validates :form_type, presence: true

  class << self
    def with_latest_intake(user_account)
      FormSubmission
        .select(select_query)
        .left_joins(:form_submission_attempts)
        .joins(latest_attempts_join)
        .where(user_account:)
    end

    def with_form_types(form_types)
      if form_types.present?
        where(form_type: form_types)
      else
        where.not(form_type: nil)
      end
    end

    def latest_pending_attempt
      form_submission_attempts.where(aasm_state: 'pending').order(created_at: :asc).last
    end

    private

    def select_query
      <<~SQL.squish
        DISTINCT form_submissions.id,
        form_submissions.form_type,
        COALESCE(latest_attempts.benefits_intake_uuid, form_submissions.benefits_intake_uuid) AS benefits_intake_uuid,
        form_submissions.created_at
      SQL
    end

    def latest_attempts_join
      <<~SQL.squish
        LEFT JOIN (
          SELECT fsa.form_submission_id, fsa.benefits_intake_uuid
          FROM form_submission_attempts fsa
          INNER JOIN (
            SELECT form_submission_id, MAX(created_at) AS latest_attempt
            FROM form_submission_attempts
            GROUP BY form_submission_id
          ) latest_fsa ON fsa.form_submission_id = latest_fsa.form_submission_id
                       AND fsa.created_at = latest_fsa.latest_attempt
        ) latest_attempts ON form_submissions.id = latest_attempts.form_submission_id
      SQL
    end
  end
end
