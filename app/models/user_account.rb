# frozen_string_literal: true

class UserAccount < ApplicationRecord
  has_many :user_verification, dependent: :destroy

  validates :icn, uniqueness: true, allow_nil: true

  def verified?
    icn.present?
  end
end
