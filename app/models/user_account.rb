# frozen_string_literal: true

class UserAccount < ApplicationRecord
  has_many :user_verifications, dependent: :destroy
  has_one :user_acceptable_verified_credential, dependent: :destroy

  validates :icn, uniqueness: true, allow_nil: true

  def verified?
    icn.present?
  end
end
