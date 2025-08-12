# frozen_string_literal: true

module V0
  class EventBusGatewayController < SignIn::ServiceAccountApplicationController
    service_tag 'event_bus_gateway'

    FEATURE_FLAGGED_EP_CODES = {
      'EP120' => :ep120_decision_letter_notifications,
      'EP180' => :ep180_decision_letter_notifications
    }.freeze

    def send_email
      # Validate required parameters
      return render json: { error: 'ep_code is required' }, status: :bad_request if send_email_params[:ep_code].blank?

      if send_email_params[:template_id].blank?
        return render json: { error: 'template_id is required' }, status: :bad_request
      end

      if decision_letter_enabled?
        # All EP codes (including EP120 and EP180) use the same LetterReadyEmailJob
        # since the email content is the same for all decision letters thus far
        EventBusGateway::LetterReadyEmailJob.perform_async(
          participant_id,
          send_email_params[:template_id],
          # include ep_code for google analytics
          send_email_params[:ep_code]
        )
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

      return false unless valid_ep_code_format?(ep_code)

      # Check if this EP code requires a feature flag
      if FEATURE_FLAGGED_EP_CODES.key?(ep_code)
        Flipper.enabled?(FEATURE_FLAGGED_EP_CODES[ep_code])
      else
        # All other EP codes (EP010, EP110, EP020, etc.) are always enabled
        true
      end
    end

    def valid_ep_code_format?(ep_code)
      # Validate ep_code is present and a string
      unless ep_code.is_a?(String) && ep_code.present?
        Rails.logger.error('Invalid ep_code format', ep_code:, participant_id:)
        return false
      end
      true
    end
  end
end
