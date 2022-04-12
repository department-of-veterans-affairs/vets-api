# frozen_string_literal: true

class UserVerification < ApplicationRecord
  has_one :deprecated_user_account, dependent: :destroy, required: false
  belongs_to :user_account, dependent: nil

  validate :single_credential_identifier

  def verified?
    verified_at.present? && user_account.verified?
  end

  private

  # XOR operators between the four credential identifiers mean one, and only one, of these can be
  # defined, If two or more are defined, or if none are defined, then a validation error is raised
  def single_credential_identifier
    unless idme_uuid.present? ^ logingov_uuid.present? ^ mhv_uuid.present? ^ dslogon_uuid.present?
      errors.add(:base, 'Must specify one, and only one, credential identifier')
    end
  end
end
