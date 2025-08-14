# frozen_string_literal: true

module V0
  class EventBusGatewayController < SignIn::ServiceAccountApplicationController
    service_tag 'event_bus_gateway'

    FEATURE_FLAGGED_EP_CODES = {
      'EP120' => :ep120_decision_letter_notifications,
      'EP180' => :ep180_decision_letter_notifications
    }.freeze

    def send_email
      # Log incoming request
      Rails.logger.info('EventBusGateway: send_email request received', 
                       ep_code: send_email_params[:ep_code],
                       template_id: send_email_params[:template_id],
                       service_account: @service_account_access_token.user_attributes['client_id'])

      if decision_letter_enabled?
        Rails.logger.info('EventBusGateway: decision_letter feature enabled, enqueuing email job', 
                         ep_code: send_email_params[:ep_code],
                         template_id: send_email_params[:template_id])
        
        # All EP codes (including EP120 and EP180) use the same LetterReadyEmailJob
        # since the email content is the same for all decision letters thus far
        email_job = EventBusGateway::LetterReadyEmailJob.perform_async(
          participant_id,
          send_email_params[:template_id],
          # include ep_code for google analytics
          send_email_params[:ep_code]
        )

        
        Rails.logger.info('EventBusGateway: email job enqueued successfully', 
                         ep_code: send_email_params[:ep_code],
                         template_id: send_email_params[:template_id],
                         email_job: email_job)
      else
        Rails.logger.info('EventBusGateway: decision_letter feature disabled, skipping email job', 
                         ep_code: send_email_params[:ep_code],
                         template_id: send_email_params[:template_id])
      end
      head :ok
    end

    private

    def participant_id
      @participant_id ||= @service_account_access_token.user_attributes['participant_id']
    end

    def send_email_params
      params.permit(:template_id, :ep_code)
    end

    def decision_letter_enabled?
      ep_code = send_email_params[:ep_code]

      # Check if this EP code requires a feature flag
      if FEATURE_FLAGGED_EP_CODES.key?(ep_code)
        Flipper.enabled?(FEATURE_FLAGGED_EP_CODES[ep_code])
      else
        # All other EP codes (EP010, EP110, EP020, etc.) are always enabled
        true
      end
    end
  end
end
