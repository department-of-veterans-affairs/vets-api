# frozen_string_literal: true

require_dependency 'claims_api/base_form_controller'
require 'jsonapi/parser'

module ClaimsApi
  module V0
    module Forms
      class DisabilityCompensationController < BaseFormController
        FORM_NUMBER = '526'
        before_action :verification_itf_expiration, only: [:submit_form_526]
        skip_before_action(:authenticate)
        skip_before_action(:verify_power_of_attorney)
        skip_before_action :validate_json_schema, only: %i[upload_supporting_documents]
        skip_before_action :verify_mvi, only: %i[submit_form_526 validate_form_526]
        skip_before_action :log_request, only: %i[validate_form_526]

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
          claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(params[:id])
          documents.each do |document|
            claim_document = claim.supporting_documents.build
            claim_document.set_file_data!(document, params[:doc_type], params[:description])
            claim_document.save!
            ClaimsApi::ClaimEstablisher.perform_async(claim_document.id)
          end

          render json: claim, serializer: ClaimsApi::ClaimDetailSerializer
        end

        def validate_form_526
          valid_service = EVSS::DisabilityCompensationForm::ServiceAllClaim.new(auth_headers)
          validation_result = valid_service.validate_form526(form_attributes.to_json)
          render json: validation_result
        rescue EVSS::ErrorMiddleware::EVSSError => e
          render json: { errors: format_errors(e.details) }, status: :unprocessable_entity
        end

        private

        def format_errors(errors)
          errors.map do |error|
            { status: 422, detail: "#{error['key']} #{error['detail']}", source: nil }
          end
        end

        def service(auth_headers)
          if Settings.claims_api.disability_claims_mock_override && !auth_headers['Mock-Override']
            ClaimsApi::DisabilityCompensation::MockOverrideService.new(
              auth_headers
            )
          else
            EVSS::DisabilityCompensationForm::ServiceAllClaim.new(
              auth_headers
            )
          end
        end

        def documents
          document_keys = params.keys.select { |key| key.include? 'attachment' }
          params.slice(*document_keys).values
        end

        def auth_headers
          evss_headers = EVSS::DisabilityCompensationAuthHeaders
                         .new(target_veteran(with_gender: true))
                         .add_headers(
                           EVSS::AuthHeaders.new(target_veteran(with_gender: true)).to_h
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
