# frozen_string_literal: true

module Mobile
  module V0
    class AppointmentPreferencesController < ApplicationController
      def show
        response = preferences_service.get_preferences
        render json: Mobile::V0::AppointmentPreferencesSerializer.new(response)
      end

      def update
        response = preferences_service.put_preferences(update_params)
        render json: Mobile::V0::AppointmentPreferencesSerializer.new(response)
      end

      private

      def preferences_service
        VAOS::PreferencesService.new(@current_user)
      end

      def update_params
        params.require(:notification_frequency)
        params.permit(:notification_frequency,
                      :email_allowed,
                      :email_address,
                      :text_msg_allowed,
                      :text_msg_ph_number)
      end
    end
  end
end
