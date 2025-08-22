# frozen_string_literal: true

class UserCredentialEmail < ApplicationRecord
  blind_index :credential_email
  belongs_to :user_verification, dependent: nil, optional: false

  has_kms_key
  has_encrypted :credential_email, key: :kms_key, **lockbox_options

  validates :credential_email_ciphertext, presence: true
end
