# frozen_string_literal: true

module ClaimsApi
  module BGSClient
    # Catalog of known BGS service actions. Check here if you need a value or if
    # it isn't here already, add it here.
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
      end
    end
  end
end
