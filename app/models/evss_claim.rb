# frozen_string_literal: true

require 'evss/documents_service'

class EVSSClaim < ApplicationRecord
  belongs_to :user_account, dependent: nil, optional: true

  def self.for_user(user)
    claim_for_user_uuid(user.uuid).or(claim_for_user_account(user.user_account))
  end

  def self.claim_for_user_uuid(user_uuid)
    return EVSSClaim.none unless user_uuid

    where(user_uuid:)
  end

  def self.claim_for_user_account(user_account)
    return EVSSClaim.none unless user_account

    where(user_account:)
  end
end
