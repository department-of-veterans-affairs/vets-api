# frozen_string_literal: true

require 'common/exceptions'
require 'jsonapi/parser'
require 'claims_api/v2/disability_compensation_validation'

module ClaimsApi
  module V2
    module Veterans
      class DisabilityCompensationController < ClaimsApi::V2::Veterans::Base
        include ClaimsApi::V2::DisabilityCompensationValidation

        FORM_NUMBER = '526'

        def submit
          validate_json_schema
          validate_form_526_submission_values!

          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers:,
            form_data: form_attributes,
            cid: token.payload['cid'],
            veteran_icn: target_veteran.mpi.icn
          )
          render json: auto_claim
        end

        def validate; end

        def attachments; end
      end
    end
  end
end
