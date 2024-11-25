# frozen_string_literal: true

require 'lighthouse/benefits_documents/constants'

class EvidenceSubmission < ApplicationRecord
  belongs_to :user_account
  has_kms_key
  has_encrypted :template_metadata, key: :kms_key, **lockbox_options

  # Lighthouse upload statuses:
  # IN_PROGRESS: the workflow is currently executing.
  # SUCCESS: the workflow has completed all steps successfully.
  # FAILED: the workflow could not complete because a step encountered a non-recoverable error.
  scope :completed, -> { where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS]) }
  scope :pending, -> { where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING]) }
  scope :failed, -> { where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED]) }
end
