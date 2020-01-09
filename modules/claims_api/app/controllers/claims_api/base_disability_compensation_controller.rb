# frozen_string_literal: true

module ClaimsApi
  class BaseDisabilityCompensationController < ClaimsApi::BaseFormController
    def upload_form_526
      pending_claim = ClaimsApi::AutoEstablishedClaim.pending?(params[:id])
      pending_claim.set_file_data!(documents.first, params[:doc_type])
      pending_claim.save!

      ClaimsApi::ClaimUploader.perform_async(pending_claim.id)

      render json: pending_claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
    end

    def validate_form_526
      service = EVSS::DisabilityCompensationForm::ServiceAllClaim.new(auth_headers)
      auto_claim = ClaimsApi::AutoEstablishedClaim.new(
        status: ClaimsApi::AutoEstablishedClaim::PENDING,
        auth_headers: auth_headers,
        form_data: form_attributes
      )
      service.validate_form526(auto_claim.to_internal)
      render json: valid_526_response
    rescue EVSS::ErrorMiddleware::EVSSError => e
      track_evss_validation_errors(e.details)
      render json: { errors: format_evss_errors(e.details) }, status: :unprocessable_entity
    end

    private

    def valid_526_response
      {
        data: {
          type: 'claims_api_auto_established_claim_validation',
          attributes: {
            status: 'valid'
          }
        }
      }.to_json
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
  end
end
