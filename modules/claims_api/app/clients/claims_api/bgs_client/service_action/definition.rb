# frozen_string_literal: true

module ClaimsApi
  module BGSClient
    module ServiceAction
      class Definition <
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
            Definition.new(
              action_name: 'readPOARequest',
              **service
            )
        end
      end
    end
  end
end
