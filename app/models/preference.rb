# frozen_string_literal: true

# Class to represent a given set of Preference choices
# @see https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Data/Databases/Vets.gov/Preferences%20Schema%20Design.md#the-winning-preferences-table-design
#
class Preference < ApplicationRecord
  has_many :user_preferences, dependent: :destroy
  has_many :preference_choices, dependent: :destroy

  validates :code,  presence: true, uniqueness: true
  validates :title, presence: true

  alias choices preference_choices

  scope :with_codes, ->(codes) { where(code: codes) }

  def self.with_choices(code)
    preference = find_by code: code

    return unless preference

    {
      preference: preference.as_json,
      preference_choices: preference.choices.as_json
    }
  end

  def to_param
    code
  end
end
