# frozen_string_literal: true

class Tooltip < ApplicationRecord
  belongs_to :user_account, inverse_of: :tooltips

  validates :tooltip_name, presence: true, uniqueness: { scope: :user_account_id }
  validates :last_signed_in, presence: true
end
