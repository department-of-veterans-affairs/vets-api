# frozen_string_literal: true

module MyHealth
  module MHVControllerConcerns
    extend ActiveSupport::Concern

    included do
      before_action :validate_mhv_correlation_id
      before_action :authorize
      before_action :authenticate_client
    end

    protected

    def validate_mhv_correlation_id
      return if current_user.mhv_correlation_id.present?

      Rails.logger.error(
        'MHV correlation ID missing for authenticated user',
        user_uuid: current_user.uuid,
        icn: current_user.icn,
        sign_in_service: current_user.identity&.sign_in&.dig(:service_name),
        loa: current_user.loa,
        controller: self.class.name,
        action: action_name
      )

      raise Common::Exceptions::Forbidden,
            detail: 'Unable to access MHV services. Please try signing in again.'
    end

    def authenticate_client
      # The authenticate method checks whether the session is expired or incomplete before authenticating.
      client.authenticate
    end
  end
end
