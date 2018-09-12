# frozen_string_literal: true

# Class to represent a given set of Preference choices
# @see https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Data/Databases/Vets.gov/Preferences%20Schema%20Design.md#the-winning-preferences-table-design
#
class Preference < ActiveRecord::Base
  has_many :user_preferences, dependent: :destroy
  has_many :preference_choices, dependent: :destroy

  validates :code,  presence: true, uniqueness: true
  validates :title, presence: true
end
