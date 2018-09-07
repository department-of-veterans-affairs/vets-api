# frozen_string_literal: true

class PreferenceChoice < ActiveRecord::Base
  belongs_to :preference
  has_many :user_preferences, dependent: :destroy

  validates :code,        presence: true, uniqueness: true
  validates :description, presence: true
end
