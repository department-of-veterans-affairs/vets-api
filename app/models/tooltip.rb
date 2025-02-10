# frozen_string_literal: true

class Tooltip < ApplicationRecord
  belongs_to :user_account, inverse_of: :tooltips
end
