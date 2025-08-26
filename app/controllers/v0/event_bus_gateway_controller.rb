# frozen_string_literal: true

module V0
  class EventBusGatewayController < SignIn::ServiceAccountApplicationController
    service_tag 'event_bus_gateway'

    FEATURE_FLAGGED_EP_CODES = {
      'EP120' => :ep120_decision_letter_notifications,
      'EP180' => :ep180_decision_letter_notifications
    }.freeze

    def send_email
      log_request_received

      if decision_letter_enabled?
        log_feature_enabled
        email_job = enqueue_email_job
        log_job_enqueued(email_job)
      else
        log_feature_disabled
      end

      head :ok
    end

    private

    def log_request_received
      Rails.logger.info('EventBusGateway: send_email request received',
                        ep_code: send_email_params[:ep_code],
                        template_id: send_email_params[:template_id],
                        service_account: @service_account_access_token.user_attributes['client_id'])
    end

    def log_feature_enabled
      Rails.logger.info('EventBusGateway: decision_letter feature enabled, enqueuing email job',
                        ep_code: send_email_params[:ep_code],
                        template_id: send_email_params[:template_id])
    end

    def log_feature_disabled
      Rails.logger.info('EventBusGateway: decision_letter feature disabled, skipping email job',
                        ep_code: send_email_params[:ep_code],
                        template_id: send_email_params[:template_id])
    end

    def enqueue_email_job
      EventBusGateway::LetterReadyEmailJob.perform_async(
        participant_id,
        send_email_params[:template_id],
        send_email_params[:ep_code]
      )
    end

    def log_job_enqueued(email_job)
      Rails.logger.info('EventBusGateway: email job enqueued successfully',
                        ep_code: send_email_params[:ep_code],
                        template_id: send_email_params[:template_id],
                        email_job:)
    end

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
