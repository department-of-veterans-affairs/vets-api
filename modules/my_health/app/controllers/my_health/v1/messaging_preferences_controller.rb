# frozen_string_literal: true

module MyHealth
  module V1
    class MessagingPreferencesController < SMController
      def show
        resource = client.get_preferences
        render json: resource,
               serializer: MessagingPreferenceSerializer
      end

      # Set secure messaging email notification preferences.
      # @param email_address - the target email address
      # @param frequency - one of 'none', 'each_message', or 'daily'
      def update
        resource = client.post_preferences(params.permit(:email_address, :frequency))
        render json: resource,
               serializer: MessagingPreferenceSerializer
      end
    end
  end
end
