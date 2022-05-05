# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionPreferencesController < RxController
      def show
        resource = client.get_preferences
        render json: resource,
               serializer: PrescriptionPreferenceSerializer
      end

      def update
        resource = client.post_preferences(params.permit(:email_address, :rx_flag))
        render json: resource,
               serializer: PrescriptionPreferenceSerializer
      end
    end
  end
end
