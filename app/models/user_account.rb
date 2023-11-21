# frozen_string_literal: true

class UserAccount < ApplicationRecord
  has_many :user_verifications, dependent: :destroy
  has_many :terms_of_use_agreements, dependent: :destroy
  has_one :user_acceptable_verified_credential, dependent: :destroy

  validates :icn, uniqueness: true, allow_nil: true

  def verified?
    icn.present?
  end

  def needs_accepted_terms_of_use?
    verified? && !accepted_current_terms_of_use?
  end

  private

  def accepted_current_terms_of_use?
    terms_of_use_agreements.current.last&.accepted?
  end
end
