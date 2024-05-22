# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class << self
        def perform(id, decision)
          id = id.split('_').last

          action =
            BGSClient::Definitions::
              ManageRepresentativeService::
              UpdatePoaRequest::
              DEFINITION

          BGSClient.perform_request(action:) do |xml, data_aliaz|
            xml[data_aliaz].POARequestUpdate do
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
      end
    end
  end
end
