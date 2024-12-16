# frozen_string_literal: true

require 'lighthouse/benefits_documents/constants'

class EvidenceSubmission < ApplicationRecord
  belongs_to :user_account
  has_kms_key
  has_encrypted :template_metadata, key: :kms_key, **lockbox_options

  scope :va_notify_email_not_sent, lambda {
    where(upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED], va_notify_date: nil)
  }
end
