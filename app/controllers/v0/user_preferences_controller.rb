# frozen_string_literal: true

module V0
  class UserPreferencesController < ApplicationController
    include Accountable

    before_action :set_account

    def create
      response = UserPreferences::Grantor.new(@account, requested_user_preferences).execute!

      render json: response, serializer: UserPreferenceSerializer
    end

    def index
      render json: user_preferences, serializer: UserPreferenceSerializer
    end

    private

    def set_account
      @account = current_user.account.presence || create_user_account
    end

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
      @user_preferences ||= UserPreference.all_preferences_with_choices(current_user.account.id)
    end
  end
end
