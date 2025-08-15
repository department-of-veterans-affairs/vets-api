# frozen_string_literal: true

require 'claims_api/v2/error/lighthouse_error_handler'

module ClaimsApi
  module PowerOfAttorneyRequestService
    class Decide
      def validate_decide_representative_params!(poa_code, representative_id)
        representative = ::Veteran::Service::Representative.find_by('? = ANY(poa_codes) AND ? = representative_id',
                                                                    poa_code, representative_id)
        unless representative
          raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
            detail: "The accredited representative with registration number #{representative_id} does not match " \
                    "poa code: #{poa_code}."
          )
        end
      end

      def get_poa_request(ptcpnt_id:, lighthouse_id:)
        service = ClaimsApi::ManageRepresentativeService.new(external_uid: Settings.bgs.external_uid,
                                                             external_key: Settings.bgs.external_key)

        res = service.read_poa_request_by_ptcpnt_id(ptcpnt_id:)
        res['poaRequestRespondReturnVOList']
        res['id'] = lighthouse_id
        res
      end
    end
  end
end
