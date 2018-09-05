# frozen_string_literal: true

class UserPreference < ActiveRecord::Base
  belongs_to :account
  belongs_to :preference
  belongs_to :preference_choice

  validates :account_id, :preference_id, :preference_choice_id, presence: true
end
