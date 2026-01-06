# frozen_string_literal: true

require 'claims_api/v2/error/lighthouse_error_handler'
require 'bgs_service/manage_representative_service'

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

      def build_veteran_and_dependent_data(request, build_target_veteran)
        vet_icn = request.veteran_icn
        claimant_icn = request.claimant_icn
        veteran_info = build_target_veteran.call(veteran_id: vet_icn, loa: { current: 3, highest: 3 })
        if claimant_icn.present?
          claimant_info = build_target_veteran.call(veteran_id: claimant_icn,
                                                    loa: { current: 3,
                                                           highest: 3 })
        end

        [veteran_info, claimant_info]
      end

      def handle_poa_response(lighthouse_id, veteran_info, claimant_info = nil)
        res = get_poa_request(ptcpnt_id: veteran_info.participant_id, lighthouse_id:)
        if claimant_info.present?
          res['claimantFirstName'] = claimant_info.first_name
          res['claimantLastName'] = claimant_info.last_name
        end

        res
      end

      def get_poa_request(ptcpnt_id:, lighthouse_id:)
        service = ClaimsApi::ManageRepresentativeService.new(external_uid: Settings.bep.external_uid,
                                                             external_key: Settings.bep.external_key)

        res = service.read_poa_request_by_ptcpnt_id(ptcpnt_id:)
        res = res['poaRequestRespondReturnVOList'] if res.present?
        res['id'] = lighthouse_id
        res
      end
    end
  end
end
