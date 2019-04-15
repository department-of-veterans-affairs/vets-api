# frozen_string_literal: true

require_dependency 'claims_api/application_controller'
require 'claims_api/form_schemas'
require 'jsonapi/parser'

module ClaimsApi
  module V1
    module Forms
      class DisabilityCompensationController < ApplicationController
        before_action { permit_scopes %w[claim.write] }
        # before_action :validate_json_api_payload

        def submit_form_526
          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes
          )
          auto_claim.form.to_internal

          ClaimsApi::ClaimEstablisher.perform_async(auto_claim.id)

          render json: auto_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
        rescue Exception => e
          render json: e.message, status: 422
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

        def validate_json_api_payload
          JSONAPI.parse_resource!(params)
        end

        def form_attributes
          attrs = JSON.parse(request.body.string)['data']['attributes']
          ClaimsApi::FormSchemas.validate!('526', attrs)
          attrs
        end

        def documents
          document_keys = params.keys.select { |key| key.include? 'attachment' }
          params.slice(*document_keys).values
        end

        def target_veteran
          @target_veteran ||= ClaimsApi::Veteran.from_headers(request.headers, with_gender: true)
        end

        def auth_headers
          EVSS::DisabilityCompensationAuthHeaders
            .new(target_veteran)
            .add_headers(
              EVSS::AuthHeaders.new(target_veteran).to_h
            )
        end
      end
    end
  end
end
