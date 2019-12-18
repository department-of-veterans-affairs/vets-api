# frozen_string_literal: true

module VAOS
  class PreferencesController < VAOS::BaseController
    def show
      response = preferences_service.get_preferences
      render json: VAOS::PreferencesSerializer.new(response)
    end

    def update
      response = preferences_service.put_preferences(put_params)
      render json: VAOS::PreferencesSerializer.new(response)
    end

    private

    def preferences_service
      VAOS::PreferencesService.new(current_user)
    end

    def put_params
      params.require(:notification_frequency)
      params.permit(:notification_frequency,
                    :email_allowed,
                    :email_address,
                    :text_msg_allowed,
                    :text_msg_ph_number)
    end
  end
end
