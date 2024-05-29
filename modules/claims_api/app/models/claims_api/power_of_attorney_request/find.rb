# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    # TODO: Find and handle some errors.
    module Find
      class << self
        def perform(id)
          participant_id, proc_id = id.split('_')

          action =
            BGSClient::Definitions::
              ManageRepresentativeService::
              ReadPoaRequestByParticipantId::
              DEFINITION

          result =
            BGSClient.perform_request(action) do |xml|
              xml.PtcpntId(participant_id)
            end

          poa_requests = Array.wrap(result['poaRequestRespondReturnVOList'])
          poa_request = poa_requests.find do |data|
            data['procID'] == proc_id
          end

          Load.perform(poa_request)
        end
      end
    end
  end
end
