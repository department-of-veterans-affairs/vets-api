# frozen_string_literal: true

class DeprecatedUserAccount < ApplicationRecord
  belongs_to :user_verification, dependent: nil
  belongs_to :user_account, dependent: :destroy

  validates :user_account, presence: true
  validates :user_verification, presence: true
end
