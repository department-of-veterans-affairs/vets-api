# frozen_string_literal: true

require_dependency 'claims_api/base_disability_compensation_controller'
require 'jsonapi/parser'

module ClaimsApi
  module V0
    module Forms
      class DisabilityCompensationController < BaseDisabilityCompensationController
        include ClaimsApi::DocumentValidations

        FORM_NUMBER = '526'

        skip_before_action(:authenticate)
        before_action :validate_json_schema, only: %i[submit_form_526 validate_form_526]
        before_action :validate_documents_content_type, only: %i[upload_supporting_documents]
        before_action :validate_documents_page_size, only: %i[upload_supporting_documents]
        skip_before_action :validate_json_format, only: %i[upload_supporting_documents]

        def submit_form_526
          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes,
            flashes: flashes,
            source: source_name
          )
          unless auto_claim.id
            auto_claim = ClaimsApi::AutoEstablishedClaim.find_by(md5: auto_claim.md5, source: source_name)
          end

          ClaimsApi::ClaimEstablisher.perform_async(auto_claim.id)

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
          super
        end
      end
    end
  end
end
