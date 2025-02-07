# frozen_string_literal: true

class Tooltip < ApplicationRecord
  belongs_to :user_account, foreign_key: :user_account_id
end
