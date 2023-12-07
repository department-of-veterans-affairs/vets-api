# frozen_string_literal: true

class FormSubmission < ApplicationRecord
  # [ TODO ]: we need some real values here
  enum form_type: {
    option1: 0,
    option2: 1
  }

  has_kms_key
  has_encrypted :form_data, key: :kms_key, **lockbox_options

  has_many :form_submission_attempts, dependent: :destroy
  belongs_to :in_progress_form, optional: true
  belongs_to :saved_claim, optional: true
  belongs_to :user_account, optional: true

  validates :benefits_intake_uuid, presence: true
  validates :form_type, presence: true
end
