# frozen_string_literal: true

require_dependency 'claims_api/base_disability_compensation_controller'
require_dependency 'claims_api/concerns/poa_verification'
require_dependency 'claims_api/concerns/document_validations'
require 'jsonapi/parser'

module ClaimsApi
  module V1
    module Forms
      class DisabilityCompensationController < BaseDisabilityCompensationController
        include ClaimsApi::PoaVerification
        include ClaimsApi::DocumentValidations

        FORM_NUMBER = '526'

        before_action { permit_scopes %w[claim.write] }
        before_action :validate_json_schema, only: %i[submit_form_526 validate_form_526]
        before_action :validate_initial_claim, only: %i[submit_form_526 validate_form_526]
        # TODO: Fix methods in document_validations to work correctly before uncommenting, add broader range of tests
        # before_action :validate_documents_content_type, only: %i[upload_supporting_documents]
        # before_action :validate_documents_page_size, only: %i[upload_supporting_documents]
        before_action :find_claim, only: %i[upload_supporting_documents]
        skip_before_action :validate_json_format, only: %i[upload_supporting_documents]

        def submit_form_526
          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes,
            source: source_name
          )
          auto_claim = ClaimsApi::AutoEstablishedClaim.find_by(md5: auto_claim.md5) unless auto_claim.id

          ClaimsApi::ClaimEstablisher.perform_async(auto_claim.id)

          render json: auto_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
        end

        def upload_supporting_documents
          documents.each do |document|
            claim_document = @claim.supporting_documents.build
            claim_document.set_file_data!(document, params[:doc_type], params[:description])
            claim_document.save!
            ClaimsApi::ClaimUploader.perform_async(claim_document.id)
          end

          render json: @claim, serializer: ClaimsApi::ClaimDetailSerializer
        end

        def validate_form_526
          super
        end

        private

        def source_name
          user = header_request? ? @current_user : target_veteran
          "#{user.first_name} #{user.last_name}"
        end

        def validate_initial_claim
          if claims_service.claims_count.zero? && form_attributes['autoCestPDFGenerationDisabled'] == false
            error = {
              errors: [
                {
                  status: 422,
                  detail: 'Veteran has no claims, autoCestPDFGenerationDisabled requires true for Initial Claim'
                }
              ]
            }
            render json: error, status: :unprocessable_entity
          end
        end

        def find_claim
          @claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(params[:id])

          unless @claim
            render(
              json: { errors: [{ status: 404, detail: "Claim not found: #{params[:id]}" }] },
              status: :not_found
            )
          end
        end
      end
    end
  end
end
