# frozen_string_literal: true

module AccreditedRepresentatives
  module V0
    # We are duplicating some functionality from `::ApplicationController`
    # because inheriting it would import inappropriate functionality, around
    # authentication for instance. Maybe we can find a refactor that gives us
    # better reuse. For now, we can try and tag the duplicative code.
    #
    # TODO: address code tagged with <duplicates-application-controller>
    class ApplicationController < ActionController::API
      # <duplicates-application-controller>
      # Though this form of reuse might be fine.
      include Traceable

      # TODO: Add ARP to Datadog Service Catalog #77004
      #   https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/77004
      # It will be the dd-service property for your application here:
      #   https://github.com/department-of-veterans-affairs/vets-api/tree/master/datadog-service-catalog
      service_tag 'accredited-representatives'

      before_action do
        if !Flipper.enabled?(:representatives_portal_api)
          # <duplicates-application-controller>
          # Duplicates `#routing_error` in combination with the
          # `ExceptionHandling` concern.
          ex = Common::Exceptions::RoutingError.new(params[:path])
          render json: { errors: ex.errors }, status: ex.status_code
        end
      end
    end
  end
end
