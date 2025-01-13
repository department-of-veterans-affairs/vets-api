# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    class Show
      def initialize(participant_id)
        @participant_id = participant_id
      end

      def get_poa_request
        service = ClaimsApi::ManageRepresentativeService.new(external_uid: Settings.bgs.external_uid,
                                                             external_key: Settings.bgs.external_key)

        res = service.read_poa_request_by_ptcpnt_id(ptcpnt_id: @participant_id)
        res['poaRequestRespondReturnVOList']
      end
    end
  end
end
