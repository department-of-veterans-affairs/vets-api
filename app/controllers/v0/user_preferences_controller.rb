# frozen_string_literal: true

module V0
  class UserPreferencesController < ApplicationController
    include Accountable

    before_action :set_account

    def create
      response = UserPreferences::Grantor.new(@account, requested_user_preferences).execute!

      render json: response, serializer: UserPreferenceSerializer
    end

    # This endpoint deletes all associated UserPreferences for a given Preference code.
    # If the Preference doesn't exist, a 404 not_found will be returned.
    #
    # @param code - Required Preference code for UserPreferences to be deleted
    #
    def delete_all
      destroy_user_preferences!
      render json: { code: params[:code] }, status: :ok, serializer: DeleteAllUserPreferencesSerializer
    end

    def index
      render json: user_preferences, serializer: UserPreferenceSerializer
    end

    private

    def set_account
      @account = create_user_account
    end

    def destroy_user_preferences!
      code = params[:code]
      raise Common::Exceptions::RecordNotFound, code if Preference.find_by(code: code).blank?

      UserPreference.for_preference_and_account(@account.id, code).each(&:destroy!)
    rescue ActiveRecord::RecordNotDestroyed => e
      err = "When destroying UserPreference records for Account #{@account.id} with "\
            "Preference code '#{code}', experienced ActiveRecord::RecordNotDestroyed "\
            "with this error: #{e}"
      raise Common::Exceptions::UnprocessableEntity.new(detail: err, source: 'UserPreferencesController')
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
      @user_preferences ||= UserPreference.all_preferences_with_choices(@account.id)
    end
  end
end
