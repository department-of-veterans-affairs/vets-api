# frozen_string_literal: true

# TEST FILE: This is a copy of form_submission.rb with ignored_columns added
# For testing the MigrationIsolator Dangerfile changes
# DO NOT MERGE THIS FILE - For testing only

class FormSubmissionTest < ApplicationRecord
  self.table_name = 'form_submissions'
  
  # Strong Migrations pattern: ignore columns before removing them
  self.ignored_columns += %w[legacy_data old_status deprecated_at]
  
  has_kms_key
  has_encrypted :form_data, key: :kms_key, **lockbox_options

  has_many :form_submission_attempts, dependent: :destroy
  belongs_to :saved_claim, optional: true
  belongs_to :user_account, optional: true

  validates :form_type, presence: true
  
  # Rest of the model code remains the same...
end