# frozen_string_literal: true

require_dependency 'claims_api/application_controller'
require 'claims_api/form_schemas'
require 'claims_api/json_api_missing_attribute'
require 'jsonapi/parser'

module ClaimsApi
  module V1
    module Forms
      class DisabilityCompensationController < BaseFormController
        FORM_NUMBER = '526'
        before_action { permit_scopes %w[claim.write] }
        skip_before_action :validate_json_schema, only: [:upload_supporting_documents]

        def submit_form_526
          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes
          )
          auto_claim.form.to_internal

          ClaimsApi::ClaimEstablisher.perform_async(auto_claim.id)

          render json: auto_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
        end

        def upload_supporting_documents
          claim = ClaimsApi::AutoEstablishedClaim.find(params[:id])
          documents.each do |document|
            claim_document = claim.supporting_documents.build
            claim_document.set_file_data!(document, params[:doc_type], params[:description])
            claim_document.save!
            ClaimsApi::ClaimEstablisher.perform_async(claim_document.id)
          end

          head :ok
        end

        private

        def documents
          document_keys = params.keys.select { |key| key.include? 'attachment' }
          params.slice(*document_keys).values
        end

        def auth_headers
          EVSS::DisabilityCompensationAuthHeaders
            .new(target_veteran(with_gender: true))
            .add_headers(
              EVSS::AuthHeaders.new(target_veteran(with_gender: true)).to_h
            )
        end
      end
    end
  end
end
