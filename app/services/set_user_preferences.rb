# frozen_string_literal: true

class SetUserPreferences
  attr_reader :account, :requested_user_preferences, :preference_codes,
              :user_preferences, :preference, :preference_choice

  def initialize(account, requested_user_preferences)
    @account = account
    @requested_user_preferences = requested_user_preferences
    @preference_codes = derive_preference_codes
  end

  def execute!
    destroy_user_preferences!

    requested_user_preferences.map do |preferences|
      assign_preference_codes preferences

      results = {
        preference: preference,
        user_preferences: []
      }

      user_preferences.each do |user_preference|
        assign_user_preference_codes user_preference
        create_user_preference!
        add_choice_to results
      end

      results
    end
  end

  private

  def derive_preference_codes
    requested_user_preferences.map { |requested| requested.dig 'preference', 'code' }
  end

  def destroy_user_preferences!
    user_prefs = UserPreference.for_preference_and_account(account.id, preference_codes)

    user_prefs.destroy_all
  end

  def assign_preference_codes(preferences)
    preference_code   = preferences.dig 'preference', 'code'
    @user_preferences = preferences.dig 'user_preferences'
    @preference       = Preference.find_by code: preference_code

    raise Common::Exceptions::RecordNotFound, preference_code if preference.blank?
  end

  def results_template
    {
      preference: preference,
      user_preferences: []
    }
  end

  def assign_user_preference_codes(user_preference)
    choice_code        = user_preference.dig 'code'
    @preference_choice = PreferenceChoice.find_by code: choice_code

    raise Common::Exceptions::RecordNotFound, choice_code if preference_choice.blank?
  end

  def create_user_preference!
    UserPreference.create!(
      account_id: account.id,
      preference_id: preference.id,
      preference_choice_id: preference_choice.id
    )
  end

  def add_choice_to(results)
    results[:user_preferences] << preference_choice
  end
end
