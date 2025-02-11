# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ApplicationController < SignIn::ApplicationController
    include SignIn::AudienceValidator
    include Authenticable
    include Pundit::Authorization

    rescue_from Pundit::NotAuthorizedError do |e|
      render(
        json: { errors: [e.message] },
        status: :forbidden
      )
    end

    service_tag 'accredited-representative-portal' # ARP DataDog monitoring: https://bit.ly/arp-datadog-monitoring
    validates_access_token_audience Settings.sign_in.arp_client_id

    before_action :verify_pilot_enabled_for_user
    around_action :handle_exceptions
    after_action :verify_pundit_authorization

    private

    def verify_pundit_authorization
      if action_name == 'index'
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

    # Returns cached VSO registration numbers authorized for current user's VA identity.
    # Caches authorization for 1 hour to avoid repeated lookups within a session.
    # @return [Array<String>] Authorized VSO registration numbers
    #
    def authorized_vso_registrations
      Rails.cache.fetch("user_#{current_user.id}_registration_numbers", expires_in: 1.hour) do
        UserAccountAccreditedIndividual.authorize_vso_representative!(
          email: current_user.email,
          icn: current_user.icn
        )
      end
    end
  end
end
