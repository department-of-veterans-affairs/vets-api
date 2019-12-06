# frozen_string_literal: true

module ClaimsApi
  class BaseDisabilityCompensationController < ClaimsApi::BaseFormController
    STATSD_VALIDATION_FAIL_KEY = 'api.claims_api.526.validation_fail'
    STATSD_VALIDATION_FAIL_TYPE_KEY = 'api.claims_api.526.validation_fail_type'

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
      track_526_validation_errors(e.details)
      render json: { errors: format_526_errors(e.details) }, status: :unprocessable_entity
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

    def format_526_errors(errors)
      errors.map do |error|
        { status: 422, detail: "#{error['key']} #{error['detail']}", source: error['key'] }
      end
    end

    def track_526_validation_errors(errors)
      StatsD.increment STATSD_VALIDATION_FAIL_KEY

      errors.each do |error|
        key = error['key'].gsub(/\[(.*?)\]/, '')
        StatsD.increment STATSD_VALIDATION_FAIL_TYPE_KEY, tags: ["key: #{key}"]
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
  end
end
