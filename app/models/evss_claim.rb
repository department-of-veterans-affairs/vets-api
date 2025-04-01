# frozen_string_literal: true

require 'evss/documents_service'

class EVSSClaim < ApplicationRecord
  belongs_to :user_account, optional: true
  validates :user_uuid, presence: true
  validates :data, presence: true

  def self.for_user(user)
    return EVSSClaim.none unless user&.user_account
    where(user_account: user.user_account)
  end

  def self.claim_for_user_account(user_account)
    return EVSSClaim.none if user_account.nil?
    where(user_account:)
  end
end
