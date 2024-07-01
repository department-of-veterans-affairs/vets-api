# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    class UpdatePowerOfAttorney
      class << self
        def perform(poa_request)
          new(poa_request).perform
        end
      end

      def initialize(poa_request)
        @poa_request = poa_request
      end

      def perform
        update_poa_relationship
      end

      private

      # I think this corresponds to what SEP reads as the current POA for a
      # Veteran rather than deriving it from either the most recently accepted
      # POA request or from the actually effective fact of the matter in BIRLS
      # and VBMS. We'll probably want to clarify a particularly tangled set of
      # race conditions here as well as business logic about precedence or
      # dependencies in how this fact propagates and gets reported in UIs.
      def update_poa_relationship
        action =
          BGSClient::Definitions::
            ManageRepresentativeService::
            UpdatePoaRelationship::
            DEFINITION

        poa_request = @poa_request # because of instance context in block below
        BGSClient.perform_request(action) do |xml, data_aliaz|
          xml[data_aliaz].POARelationship do
            xml.vsoPOACode(poa_request.power_of_attorney_code)

            xml.vetPtcpntId(poa_request.veteran.participant_id)
            xml.vetFileNumber(poa_request.veteran.file_number)
            xml.vetSSN(poa_request.veteran.ssn)

            xml.dateRequestAccepted(
              PowerOfAttorneyRequest::Utilities::Dump.time(Time.current)
            )
          end
        end
      end
    end
  end
end
