# frozen_string_literal: true

class EvidenceSubmission < ApplicationRecord
  belongs_to :user_account
  has_kms_key
  has_encrypted :template_metadata, key: :kms_key, **lockbox_options
  # attr_accessor :upload_status, :delete_date
end
