# frozen_string_literal: true

require 'common/exceptions'
require 'jsonapi/parser'
require 'claims_api/v2/disability_compensation_validation'
require 'claims_api/v2/disability_compensation_pdf_mapper'
require 'claims_api/v2/disability_compensation_evss_mapper'
require 'evss_service/base'
require 'pdf_generator_service/pdf_client'

module ClaimsApi
  module V2
    module Veterans
      class DisabilityCompensationController < ClaimsApi::V2::Veterans::Base
        include ClaimsApi::V2::DisabilityCompensationValidation

        FORM_NUMBER = '526'

        before_action :verify_access!
        before_action :shared_validation, only: %i[submit validate]

        def submit
          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers:,
            form_data: form_attributes,
            cid: token.payload['cid'],
            veteran_icn: target_veteran.mpi.icn
          )
          track_pact_counter auto_claim
          pdf_data = get_pdf_data
          pdf_mapper_service(form_attributes, pdf_data, target_veteran).map_claim

          generate_526_pdf(pdf_data)
          get_benefits_documents_auth_token unless Rails.env.test?

          render json: auto_claim
        end

        def validate
          render json: valid_526_response
        end

        def attachments; end

        def get_pdf
          # Returns filled out 526EZ form as PDF
        end

        private

        def shared_validation
          validate_json_schema
          validate_form_526_submission_values!
        end

        def valid_526_response
          {
            data: {
              type: 'claims_api_auto_established_claim_validation',
              attributes: {
                status: 'valid'
              }
            }
          }
        end

        def generate_526_pdf(pdf_data)
          pdf_data[:data] = pdf_data[:data][:attributes]
          client = PDFClient.new(pdf_data.to_json)
          client.generate_pdf
        end

        def pdf_mapper_service(auto_claim, pdf_data, target_veteran)
          ClaimsApi::V2::DisabilityCompensationPdfMapper.new(auto_claim, pdf_data, target_veteran)
        end

        def evss_mapper_service(auto_claim)
          ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim)
        end

        def track_pact_counter(claim)
          return unless form_attributes['disabilities']&.map { |d| d['isRelatedToToxicExposure'] }&.include? true

          # Fetch the claim by md5 if it doesn't have an ID (given duplicate md5)
          if claim.id.nil? && claim.errors.find { |e| e.attribute == :md5 }&.type == :taken
            claim = ClaimsApi::AutoEstablishedClaim.find_by(md5: claim.md5) || claim
          end

          ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT',
                                            consumer_label: token.payload['label'] || token.payload['cid']
        end

        def get_pdf_data
          {
            data: {}
          }
        end

        def evss_service
          ClaimsApi::EVSSService::Base.new(request)
        end
      end
    end
  end
end
