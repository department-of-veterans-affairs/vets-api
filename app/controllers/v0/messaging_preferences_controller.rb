# frozen_string_literal: true

module V0
  class MessagingPreferencesController < MyHealth::SMController
    def show
      resource = client.get_preferences
      render json: MessagingPreferenceSerializer.new(resource)
    end

    # Set secure messaging email notification preferences.
    # @param email_address - the target email address
    # @param frequency - one of 'none', 'each_message', or 'daily'
    def update
      resource = client.post_preferences(params.permit(:email_address, :frequency))
      render json: MessagingPreferenceSerializer.new(resource)
    end
  end
end
