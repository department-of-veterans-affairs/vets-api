# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'
require 'claims_api/v2/params_validation/power_of_attorney'
require 'claims_api/v2/error/lighthouse_error_handler'
require 'claims_api/v2/json_format_validation'

module ClaimsApi
  module V2
    module Veterans
      class PowerOfAttorney::OrganizationController < ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController
        FORM_NUMBER = '2122'

        def submit
          shared_form_validation(FORM_NUMBER)
          validate_veteran_name(false)
          poa_code = get_poa_code(FORM_NUMBER)
          validate_org_poa_code!(poa_code)

          submit_power_of_attorney(poa_code, FORM_NUMBER)
        end

        def validate
          shared_form_validation(FORM_NUMBER)
          validate_veteran_name(false)
          poa_code = get_poa_code(FORM_NUMBER)
          validate_org_poa_code!(poa_code)

          render json: validation_success('21-22')
        end

        private

        def validate_org_poa_code!(poa_code)
          return if ::Veteran::Service::Organization.exists?(poa: poa_code)

          raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
            detail: "Could not find an Organization with code: #{poa_code}"
          )
        end
      end
    end
  end
end
