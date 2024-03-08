# frozen_string_literal: true

module AccreditedRepresentatives
  class ApplicationController < ::ApplicationController
    # TODO: Add ARP to Datadog Service Catalog #77004
    #   https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/77004
    # It will be the dd-service property for your application here:
    #   https://github.com/department-of-veterans-affairs/vets-api/tree/master/datadog-service-catalog
    service_tag 'accredited-representatives'

    before_action :verify_feature_enabled!

    private

    def authenticate
      # NOTE: this is currently a copy of app/controllers/concerns/authentication_and_sso_concerns.rb
      # TODO: override the default authenticate method to use accredited representative authentication
      if cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME]
        super
      else
        validate_session || render_unauthorized
      end
    end

    def verify_feature_enabled!
      return if Flipper.enabled?(:representatives_portal_api)

      routing_error
    end
  end
end
