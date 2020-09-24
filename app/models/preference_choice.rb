# frozen_string_literal: true

# Class to represent a single choice in a set of Preferences
# @see https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Data/Databases/Vets.gov/Preferences%20Schema%20Design.md#the-winning-preferences-table-design
#
class PreferenceChoice < ApplicationRecord
  belongs_to :preference
  has_many :user_preferences, dependent: :destroy

  validates :code,        presence: true, uniqueness: true
  validates :description, presence: true
end
