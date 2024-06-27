# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Decision
      module Create
        class << self
          def perform(id, decision)
            action =
              BGSClient::Definitions::
                ManageRepresentativeService::
                UpdatePoaRequest::
                DEFINITION

            BGSClient.perform_request(action) do |xml, data_aliaz|
              Dump.perform(id, decision, xml, data_aliaz)
            end
          end
        end
      end
    end
  end
end
