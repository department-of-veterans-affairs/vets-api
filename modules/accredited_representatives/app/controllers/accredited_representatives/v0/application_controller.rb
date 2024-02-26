# frozen_string_literal: true

module AccreditedRepresentatives
  module V0
    class ApplicationController < ApplicationController
      # Add this `service_tag` to the Datadog Service Catalog.
      #   https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/77004
      # It will be the dd-service property for your application here:
      #   https://github.com/department-of-veterans-affairs/vets-api/tree/master/datadog-service-catalog
      service_tag 'accredited-representatives'
    end
  end
end
