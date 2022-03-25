# frozen_string_literal: true

class InheritedProofVerifiedUserAccount < ApplicationRecord
  belongs_to :user_account

  validates :user_account, uniqueness: true, presence: true
end
