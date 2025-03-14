# frozen_string_literal: true

require 'lighthouse/benefits_documents/constants'

class EvidenceSubmission < ApplicationRecord
  belongs_to :user_account
  has_kms_key
  has_encrypted :template_metadata, key: :kms_key, **lockbox_options

  # Lighthouse upload statuses:
  # CREATED: the evidence submission record is created.
  # QUEUED: the evidence submission record has been given a job id.
  # IN_PROGRESS: the evidence submission record is sent to Lighthouse.
  # SUCCESS: the evidence submission record has been sent to EVSS or added to the e-folder.
  # FAILED: the evidence submission record could not complete because a step encountered a non-recoverable error.
  scope :created, -> { where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:CREATED]) }
  scope :queued, -> { where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:QUEUED]) }
  scope :pending, -> { where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING]) }
  scope :completed, -> { where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS]) }
  scope :failed, -> { where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED]) }
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
