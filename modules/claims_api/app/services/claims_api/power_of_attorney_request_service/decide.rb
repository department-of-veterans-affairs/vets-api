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
    end
  end
end
