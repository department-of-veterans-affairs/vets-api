# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ApplicationController < ::ApplicationController
    # TODO: Add ARP to Datadog Service Catalog #77004
    #   https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/77004
    # It will be the dd-service property for your application here:
    #   https://github.com/department-of-veterans-affairs/vets-api/tree/master/datadog-service-catalog
    service_tag 'accredited-representative-portal'

    before_action :verify_feature_enabled!

    # TODO: Integrate SignIn Service to ARP Engine #76157
    #   https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/76157
    skip_before_action :authenticate

    private

    def verify_feature_enabled!
      return if Flipper.enabled?(:accredited_representative_portal_api)

      routing_error
    end

    def current_user
      nil
    end
  end
end
