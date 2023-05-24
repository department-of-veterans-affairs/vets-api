# frozen_string_literal: true

require 'common/exceptions'
require 'jsonapi/parser'
require 'claims_api/v2/disability_compensation_validation'
require 'claims_api/v2/disability_compensation_pdf_mapper'
require 'evss_service/base'

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
          pdf_data = get_pdf_data
          pdf_mapper_service(form_attributes, pdf_data).map_claim

          # evss_service.submit(auto_claim)

          render json: auto_claim
        end

        def validate; end

        def attachments; end

        private

        def pdf_mapper_service(auto_claim, pdf_data)
          ClaimsApi::V2::DisabilityCompensationPdfMapper.new(auto_claim, pdf_data)
        end

        def get_pdf_data
          {
            data: {
              attributes:
                {}
            }
          }
        end

        def evss_service
          ClaimsApi::EVSSService::Base.new(request)
        end
      end
    end
  end
end
