# frozen_string_literal: true

module V0
  class UserPreferencesController < ApplicationController
    include Accountable

    def create
      account  = current_user.account.presence || create_user_account
      response = SetUserPreferences.new(account, requested_user_preferences).execute!

      render json: response, serializer: UserPreferenceSerializer
    end

    def index
      render json: user_preferences, serializer: UserPreferenceSerializer
    end

    private

    def user_preference_params
      params.permit(
        _json: [
          {
            preference: [:code]
          },
          {
            user_preferences: [:code]
          }
        ]
      )
    end

    def requested_user_preferences
      user_preference_params['_json']
    end

    def user_preferences
      @user_preferences ||= UserPreference.all_preferences_with_choices(current_user.account_id)
    end
  end
end
