# frozen_string_literal: true

module V0
  class EventBusGatewayController < SignIn::ServiceAccountApplicationController
    service_tag 'event_bus_gateway'

    def send_email
      template_id = send_email_params.require(:template_id)
      final_template_id = select_email_template(template_id)

      EventBusGateway::LetterReadyEmailJob.perform_async(
        participant_id,
        final_template_id
      )
      head :ok
    end

    def send_push
      EventBusGateway::LetterReadyPushJob.perform_async(
        participant_id,
        send_push_params.require(:template_id)
      )
      head :ok
    end

    def send_notifications
      validate_at_least_one_template!
      return if performed?

      email_template_id = send_notifications_params[:email_template_id]
      final_email_template_id = email_template_id.present? ? select_email_template(email_template_id) : nil

      EventBusGateway::LetterReadyNotificationJob.perform_async(
        participant_id,
        final_email_template_id,
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

    def validate_at_least_one_template!
      return if send_notifications_params[:email_template_id].present? ||
                send_notifications_params[:push_template_id].present?

      render json: {
        errors: [{
          title: 'Bad Request',
          detail: 'At least one of email_template_id or push_template_id is required',
          status: '400'
        }]
      }, status: :bad_request
    end

    def select_email_template(default_template_id)
      # Check if this is a decision letter email and if universal link flag is enabled
      decision_letter_template_id = Settings.vanotify.services.benefits_management_tools.template_id
                                            .decision_letter_ready_email

      if default_template_id == decision_letter_template_id && universal_link_enabled?
        # Use universal link template
        universal_link_template_id = Settings.vanotify.services.benefits_management_tools.template_id
                                             .decision_letter_ready_email_universal_link

        if universal_link_template_id.present?
          Rails.logger.info(
            'EventBusGatewayController using universal link template',
            {
              original_template: default_template_id,
              universal_link_template: universal_link_template_id
            }
          )
          return universal_link_template_id
        end
      end

      default_template_id
    end

    def universal_link_enabled?
      # Use participant_id as the actor for percentage-based rollout
      # This avoids expensive BGS/MPI calls just for feature flag checks
      Flipper.enabled?(:event_bus_gateway_letter_ready_email_universal_link, Flipper::Actor.new(participant_id))
    end
  end
end
