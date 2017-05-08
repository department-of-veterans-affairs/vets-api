# frozen_string_literal: true
module V0
  class MessagingPreferencesController < SMController
    def show
      resource = client.get_preferences
      puts resource
      render json: resource,
             serializer: MessagingPreferenceSerializer
    end

    def update
      client.post_preferences(sanitize_params)
      render nothing: true, status: :accepted
    end

    private

    def sanitize_params
      params.require(:email_address)
      params.require(:frequency)
      client_param = MessagingPreference::FREQUENCY_UPDATE_MAP[params[:frequency]]
      raise Common::Exceptions::InvalidFieldValue.new('frequency', params[:frequency]) if client_param.nil? 
      { email_address: params[:email_address], notify_me: client_param }
    end

  end
end
