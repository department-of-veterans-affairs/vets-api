# frozen_string_literal: true

module V0
  class EventBusGatewayController < SignIn::ServiceAccountApplicationController
    service_tag 'event_bus_gateway'

    def send_email
      if Flipper.enabled?(:event_bus_gateway_emails_enabled)
        EventBusGateway::LetterReadyEmailJob.perform_async(
          participant_id,
          send_email_params[:template_id]
        )
      end
      head :ok
    end

    private

    def participant_id
      @participant_id ||= @service_account_access_token.user_attributes['participant_id']
    end

    def send_email_params
      params.permit(:template_id)
    end
  end
end
