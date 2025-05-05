# frozen_string_literal: true

module V0
  class EventBusGatewayController < ApplicationController
    service_tag 'event_bus_gateway'

    skip_before_action :authenticate, only: :send_email
    EMAIL_PARAMS = %i[
      participant_id
      template_id
      personalisation
    ].freeze

    def send_email
      if Flipper.enabled?(:event_bus_gateway_emails_enabled)
        EventBusGateway::LetterReadyEmailJob.perform_async(
          participant_id: send_email_params[:participant_id],
          template_id: send_email_params[:template_id],
          personalisation: send_email_params[:personalisation]
        )
      end
      head :ok
    end

    private

    def send_email_params
      params.permit(EMAIL_PARAMS)
    end
  end
end
