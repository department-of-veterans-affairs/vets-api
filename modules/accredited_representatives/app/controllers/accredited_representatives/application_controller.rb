# frozen_string_literal: true

module AccreditedRepresentatives
  # TODO: refactor and inherit from some global controller
  class ApplicationController < DuplicativeGlobalApplicationController
    # TODO: Add ARP to Datadog Service Catalog #77004
    #   https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/77004
    # It will be the dd-service property for your application here:
    #   https://github.com/department-of-veterans-affairs/vets-api/tree/master/datadog-service-catalog
    service_tag 'accredited-representatives'

    before_action do
      if !Flipper.enabled?(:representatives_portal_api)
        routing_error
      end
    end

    private

    def current_user
      nil
    end
  end
end
