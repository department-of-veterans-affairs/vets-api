# frozen_string_literal: true

class UserAcceptableVerifiedCredential < ApplicationRecord
  belongs_to :user_account, dependent: nil, optional: false

  scope :with_avc,        -> { where.not(acceptable_verified_credential_at: nil) }
  scope :with_ivc,        -> { where.not(idme_verified_credential_at: nil) }
  scope :without_avc,     -> { where(acceptable_verified_credential_at: nil) }
  scope :without_ivc,     -> { where(idme_verified_credential_at: nil) }
  scope :without_avc_ivc, -> { where(acceptable_verified_credential_at: nil, idme_verified_credential_at: nil) }
end
