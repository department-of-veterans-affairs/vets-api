# frozen_string_literal: true

module V0
  class EventBusGatewayController < SignIn::ServiceAccountApplicationController
    service_tag 'event_bus_gateway'

    def send_email
      EventBusGateway::LetterReadyEmailJob.perform_async(
        participant_id,
        send_email_params[:template_id]
      )
      head :ok
    end

    def send_push
      EventBusGateway::LetterReadyPushJob.perform_async(
        participant_id,
        send_push_params[:template_id]
      )
      head :ok
    end

    def send_notifications
      EventBusGateway::LetterReadyNotificationJob.perform_async(
        participant_id,
        send_notifications_params[:email_template_id],
        send_notifications_params[:push_template_id]
      )
      head :ok
    end

    private

    def participant_id
      @participant_id ||= @service_account_access_token.user_attributes['participant_id']
    end

    def send_email_params
      params.permit(:template_id)
    end

    def send_push_params
      params.permit(:template_id)
    end

    def send_notifications_params
      params.permit(:email_template_id, :push_template_id)
    end
  end
end
