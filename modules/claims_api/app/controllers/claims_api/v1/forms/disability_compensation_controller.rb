# frozen_string_literal: true

require_dependency 'claims_api/base_disability_compensation_controller'
require_dependency 'claims_api/concerns/poa_verification'
require_dependency 'claims_api/concerns/page_size_validation'
require 'jsonapi/parser'

module ClaimsApi
  module V1
    module Forms
      class DisabilityCompensationController < BaseDisabilityCompensationController
        include ClaimsApi::PoaVerification
        include ClaimsApi::PageSizeValidation

        FORM_NUMBER = '526'

        before_action { permit_scopes %w[claim.write] }
        before_action :validate_json_schema, only: %i[submit_form_526 validate_form_526]
        before_action :validate_initial_claim, only: %i[submit_form_526 validate_form_526]
        before_action :validate_documents_page_size, only: %i[upload_supporting_documents]

        def submit_form_526
          service_object = service(auth_headers)
          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes,
            source: source_name
          )
          auto_claim = ClaimsApi::AutoEstablishedClaim.find_by(md5: auto_claim.md5) unless auto_claim.id
          service_object.validate_form526(auto_claim.form.to_internal)

          ClaimsApi::ClaimEstablisher.perform_async(auto_claim.id)

          render json: auto_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
        rescue EVSS::ErrorMiddleware::EVSSError => e
          track_526_validation_errors(e.details)
          render json: { errors: format_errors(e.details) }, status: :unprocessable_entity
        end

        def upload_form_526
          service_object = service(auth_headers)
          pending_claim = ClaimsApi::AutoEstablishedClaim.pending?(params[:id]))
          pending_claim.set_file_data!(documents.first, params[:doc_type])
          pending_claim.save!
          
          ClaimsApi::ClaimUploader.perform_async(pending_claim.id)
          
          render json: auto_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
        end

        def upload_supporting_documents
          claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(params[:id])
          documents.each do |document|
            claim_document = claim.supporting_documents.build
            claim_document.set_file_data!(document, params[:doc_type], params[:description])
            claim_document.save!
            ClaimsApi::ClaimUploader.perform_async(claim_document.id)
          end

          render json: claim, serializer: ClaimsApi::ClaimDetailSerializer
        end

        def validate_form_526
          service = EVSS::DisabilityCompensationForm::ServiceAllClaim.new(auth_headers)
          auto_claim = ClaimsApi::AutoEstablishedClaim.new(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes
          )
          service.validate_form526(auto_claim.form.to_internal)
          render json: valid_526_response
        rescue EVSS::ErrorMiddleware::EVSSError => e
          track_526_validation_errors(e.details)
          render json: { errors: format_526_errors(e.details) }, status: :unprocessable_entity
        end

        private

        def source_name
          user = poa_request? ? @current_user : target_veteran
          "#{user.first_name} #{user.last_name}"
        end

        def validate_initial_claim
          if claims_service.claims_count.zero? && form_attributes['autoCestPDFGenerationDisabled'] == false
            error = {
              errors: [
                {
                  status: 422,
                  details: 'Veteran has no claims, autoCestPDFGenerationDisabled requires true for Initial Claim'
                }
              ]
            }
            render json: error, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
