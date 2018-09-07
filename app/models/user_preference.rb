# frozen_string_literal: true

# Class to represent a single user choice for a single PreferenceChoice
# @see https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Data/Databases/Vets.gov/Preferences%20Schema%20Design.md#the-winning-preferences-table-design
#
class UserPreference < ActiveRecord::Base
  belongs_to :account
  belongs_to :preference
  belongs_to :preference_choice

  validates :account_id, :preference_id, :preference_choice_id, presence: true
end
