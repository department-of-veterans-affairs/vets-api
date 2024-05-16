# frozen_string_literal: true

module ClaimsApi
  module BGSClient
    ##
    # Catalog of known BGS service actions. Check here if you need a value or if
    # it isn't here already, add it here.
    #
    # Here is a catalog of BGS services:
    #   https://github.com/department-of-veterans-affairs/bgs-catalog
    #
    # And then check files that look like this:
    #   `VDC/ManageRepresentativeService/ManageRepresentativePortBinding/readPOARequest/request.xml`
    #   `VDC/ManageRepresentativeService/ManageRepresentativePortBinding/readPOARequest/response.xml`
    class ServiceAction <
      Data.define(
        :service_path,
        :service_namespaces,
        :action_name
      )

      module ManageRepresentativeService
        service = {
          service_path: 'VDC/ManageRepresentativeService',
          service_namespaces: { 'data' => '/data' }
        }

        ReadPoaRequest =
          ServiceAction.new(
            action_name: 'readPOARequest',
            **service
          )

        UpdatePoaRequest =
          ServiceAction.new(
            action_name: 'updatePOARequest',
            **service
          )
      end
    end
  end
end
