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
  scope :failed, -> { where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED]) }
  scope :pending, -> { where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING]) }
  # used for sending failure notification emails
  scope :va_notify_email_queued, lambda {
    where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED])
      .where.not(va_notify_date: nil)
      .where.not(va_notify_id: nil)
  }
  # used for sending failure notification emails
  scope :va_notify_email_not_queued, lambda {
    where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED], va_notify_id: nil, va_notify_date: nil)
  }

  def completed?
    upload_status == BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS]
  end

  def failed?
    upload_status == BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED]
  end

  def pending?
    upload_status == BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING]
  end
end
