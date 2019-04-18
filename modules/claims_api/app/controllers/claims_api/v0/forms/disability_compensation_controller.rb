# frozen_string_literal: true

require_dependency 'claims_api/application_controller'
require 'jsonapi/parser'
require 'claims_api/form_schemas'
require 'claims_api/json_api_missing_attribute'
module ClaimsApi
  module V0
    module Forms
      class DisabilityCompensationController < BaseFormController
        FORM_NUMBER = '526'
        skip_before_action(:authenticate)
        skip_before_action(:verify_power_of_attorney)
        skip_before_action :validate_json_schema, only: [:upload_supporting_documents]

        def submit_form_526
          auto_claim = ClaimsApi::AutoEstablishedClaim.create(
            status: ClaimsApi::AutoEstablishedClaim::PENDING,
            auth_headers: auth_headers,
            form_data: form_attributes
          )
          auto_claim = ClaimsApi::AutoEstablishedClaim.find_by(md5: auto_claim.md5) unless auto_claim.id
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

        def target_veteran
          @target_veteran ||= ClaimsApi::Veteran.from_headers(request.headers, with_gender: true)
        end

        def auth_headers
          evss_headers = EVSS::DisabilityCompensationAuthHeaders
                         .new(target_veteran)
                         .add_headers(
                           EVSS::AuthHeaders.new(target_veteran).to_h
                         )
          if request.headers['Mock-Override'] &&
             Settings.claims_api.disability_claims_mock_override
            evss_headers['Mock-Override'] = true
            Rails.logger.info('ClaimsApi: Mock Override Engaged')
          end

          evss_headers
        end
      end
    end
  end
end
