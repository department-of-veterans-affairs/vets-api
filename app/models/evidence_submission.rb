# frozen_string_literal: true

class EvidenceSubmission < ApplicationRecord
  belongs_to :user_account
  has_kms_key
  has_encrypted :template_metadata, key: :kms_key, **lockbox_options

  # Lighthouse upload statuses:
  # IN_PROGRESS: the workflow is currently executing.
  # SUCCESS: the workflow has completed all steps successfully.
  # FAILED: the workflow could not complete because a step encountered a non-recoverable error.
  scope :completed, -> { where(upload_status: 'SUCCESS') } # TODO: make sure scopes use user_account
  scope :pending, -> { where(upload_status: 'IN_PROGRESS') }
  scope :failed, -> { where(upload_status: 'FAILED') }
end
