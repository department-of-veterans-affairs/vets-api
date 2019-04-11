# frozen_string_literal: true

# Class to represent a single user choice for a single PreferenceChoice
# @see https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Data/Databases/Vets.gov/Preferences%20Schema%20Design.md#the-winning-preferences-table-design
#
class UserPreference < ApplicationRecord
  belongs_to :account
  belongs_to :preference
  belongs_to :preference_choice

  validates :account_id, :preference_id, :preference_choice_id, presence: true
  validates(
    :account_id,
    uniqueness: {
      scope: :preference_choice_id,
      message: 'already has a UserPreference record with this PreferenceChoice'
    }
  )

  scope :for_account, ->(account_id) { where(account_id: account_id) }

  def self.for_preference_and_account(account_id, preference_codes)
    UserPreference
      .joins(:preference)
      .merge(Preference.with_codes(preference_codes))
      .for_account(account_id)
  end

  # A user can have many UserPreferences which represent a given PreferenceChoice.
  # This method will return an array of objects including each Preference and the
  # associated choices those which the User has opted-in
  #
  # @return [Array] an array of objects with paired Preference/UserPreference objects
  #
  def self.all_preferences_with_choices(account_id)
    results = []
    user_preferences = for_account(account_id).eager_load(:preference, :preference_choice)
    user_preferences.to_a.group_by(&:preference_id).each do |up|
      preference = extract_preference(up)
      results += [{
        preference: preference,
        user_preferences: extract_choices(user_preferences, preference)
      }]
    end
    results
  end

  class << self
    # This method digs out the preference for a set of UserPreferences
    #
    # @param user_preference [Array<Array>]
    # @example
    # [
    #     1082,
    #     [
    #        #<UserPreference:0x000056334aafec30> {
    #                               :id => 297,
    #                       :account_id => 1,
    #                   :preference_id => 1082,
    #             :preference_choice_id => 3870,
    #                      :created_at => Wed, 05 Dec 2018 17:35:02 UTC +00:00,
    #                       :updated_at => Wed, 05 Dec 2018 17:35:02 UTC +00:00
    #         }
    #     ]
    # ]
    #
    # @return [Preference] A Preference object
    #
    def extract_preference(user_preference)
      user_preference[1][0].preference
    end

    def extract_choices(user_preferences, preference)
      user_preferences.select { |el| el.preference_id == preference.id }.map(&:preference_choice)
    end
  end
end
