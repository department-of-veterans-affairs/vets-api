# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class << self
        def perform(id, decision)
          BGSClient.perform_request(
            body: dump(id, decision),
            service_action:
          )
        end

        private

        def dump(id, decision)
          Helpers::XmlBuilder.perform(service_action) do |xml, aliaz|
            xml[aliaz].POARequestUpdate do
              xml.procId(id)

              xml.secondaryStatus(decision[:status])
              xml.declinedReason(decision[:declinedReason])
              xml.dateRequestActioned(Time.current.iso8601)

              representative = decision[:representative]
              xml.VSOUserEmail(representative[:email])
              xml.VSOUserFirstName(representative[:firstName])
              xml.VSOUserLastName(representative[:lastName])
            end
          end
        end

        def service_action
          BGSClient::ServiceAction::
            ManageRepresentativeService::
            UpdatePoaRequest
        end
      end
    end
  end
end
