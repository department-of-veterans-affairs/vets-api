# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    module Find
      class << self
        def perform(id) # rubocop:disable Metrics/MethodLength
          participant_id, proc_id = id.split('_')

          action =
            BGSClient::Definitions::
              VeteranRepresentativeService::
              ReadAllVeteranRepresentatives::
              DEFINITION

          result =
            BGSClient.perform_request(action) do |xml, data_aliaz|
              xml[data_aliaz].CorpPtcpntIdFormTypeCode do
                xml.formTypeCode('21-22')
                xml.veteranCorpPtcpntId(participant_id)
              end
            end

          poa_request =
            Array.wrap(result).find do |data|
              data['procId'] == proc_id
            end

          poa_request.nil? and
            raise ::Common::Exceptions::RecordNotFound, id

          Load.perform(
            participant_id,
            poa_request
          )
        end
      end
    end
  end
end
