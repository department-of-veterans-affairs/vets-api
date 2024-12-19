# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ApplicationController < SignIn::ApplicationController
    include SignIn::AudienceValidator
    include Authenticable
    include Pundit::Authorization

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    service_tag 'accredited-representative-portal' # ARP DataDog monitoring: https://bit.ly/arp-datadog-monitoring
    validates_access_token_audience Settings.sign_in.arp_client_id

    before_action :verify_pilot_enabled_for_user
    around_action :handle_exceptions
    after_action :verify_pundit_authorization

    private

    def user_not_authorized
      render json: { error: "You are not authorized to perform this action." }, status: :unauthorized
    end

    def verify_pundit_authorization
      if action_name == "index"
        verify_policy_scoped
      else
        verify_authorized
      end
    end
    def handle_exceptions
      yield
    rescue => e
      Rails.logger.error("ARP: Unexpected error occurred for user with user_uuid=#{@current_user&.uuid} - #{e.message}")
      raise e
    end

    def verify_pilot_enabled_for_user
      unless Flipper.enabled?(:accredited_representative_portal_pilot, @current_user)
        message = 'The accredited_representative_portal_pilot feature flag is disabled ' \
                  "for the user with uuid: #{@current_user.uuid}"

        raise Common::Exceptions::Forbidden, detail: message
      end
    end
  end
end
