# frozen_string_literal: true

class PreferenceChoice < ActiveRecord::Base
  has_many :user_preferences, dependent: :destroy
  has_many :preferences, through: :user_preferences

  validates :code,        presence: true, uniqueness: true
  validates :description, presence: true
end
