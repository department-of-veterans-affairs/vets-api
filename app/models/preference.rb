# frozen_string_literal: true

class Preference < ActiveRecord::Base
  has_many :user_preferences, dependent: :destroy
  has_many :preference_choices, dependent: :destroy

  validates :code,  presence: true, uniqueness: true
  validates :title, presence: true
end
