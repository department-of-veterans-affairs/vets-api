# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'
require 'claims_api/v2/params_validation/power_of_attorney'
require 'claims_api/v2/error/lighthouse_error_handler'
require 'claims_api/v2/json_format_validation'

module ClaimsApi
  module V2
    module Veterans
      class PowerOfAttorney::IndividualController < ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController
        FORM_NUMBER = '2122a'

        def submit2122a
          shared_form_validation('2122A')
          poa_code = get_poa_code('2122A')
          validate_individual_poa_code!(poa_code)

          submit_power_of_attorney(poa_code, '2122A')
        end

        def validate2122a
          shared_form_validation('2122A')
          poa_code = get_poa_code('2122A')
          validate_individual_poa_code!(poa_code)

          render json: validation_success('21-22a')
        end

        private

        def validate_individual_poa_code!(poa_code)
          return if ::Veteran::Service::Representative.where('? = ANY(poa_codes)', poa_code).any?

          raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
            detail: "Could not find an Accredited Representative with code: #{poa_code}"
          )
        end

        def parse_and_validate_poa_code(form_number)
          poa_code = get_poa_code(form_number)
          validate_poa_code!(poa_code)
          validate_poa_code_for_current_user!(poa_code) if user_is_representative?

          poa_code
        end
      end
    end
  end
end
