# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'
require_dependency 'claims_api/json_api_missing_attribute'

module ClaimsApi
  class BaseFormController < ClaimsApi::ApplicationController
    before_action :validate_json_schema

    STATSD_VALIDATION_FAIL_KEY = 'api.claims_api.526.validation_fail'
    STATSD_VALIDATION_FAIL_TYPE_KEY = 'api.claims_api.526.validation_fail_type'

    # schema endpoint should be wide open
    skip_before_action :validate_json_schema, only: %i[schema]
    skip_before_action :authenticate, only: %i[schema]
    skip_before_action :verify_power_of_attorney, only: %i[schema]
    skip_before_action :verify_mvi, only: %i[schema]
    skip_before_action :log_request, only: %i[schema]

    def schema
      render json: { data: [ClaimsApi::FormSchemas::SCHEMAS[self.class::FORM_NUMBER]] }
    end

    private

    def verification_itf_expiration
      active = itf_service.get_active('compensation')
      if !active['intent_to_file'] || active['intent_to_file'].expiration_date < Time.now.utc
        error = {
          errors: [
            {
              status: 422,
              details: 'Intent to File Expiration Date not valid, resubmit ITF.'
            }
          ]
        }
        render json: error, status: 422
      end
    end

    def itf_service
      EVSS::IntentToFile::Service.new(target_veteran)
    end

    def validate_json_schema
      ClaimsApi::FormSchemas.validate!(self.class::FORM_NUMBER, form_attributes)
    rescue ClaimsApi::JsonApiMissingAttribute => e
      render json: e.to_json_api, status: e.code
    end

    def form_attributes
      payload_attributes = JSON.parse(request.body.string).dig('data', 'attributes') if request.body.string.present?

      payload_attributes ||= {}

      payload_attributes
    end

    def validate_526_payload
      service = EVSS::DisabilityCompensationForm::ServiceAllClaim.new(auth_headers)
      service.validate_form526(form_attributes.to_json)
    rescue EVSS::ErrorMiddleware::EVSSError => e
      track_526_validation_errors(e)
      render json: { errors: format_errors(e.details) }, status: :unprocessable_entity
    end

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

    def track_526_validation_errors
      StatsD.increment STATSD_VALIDATION_FAIL_KEY

      errors.map do |error|
        key = error['key'].gsub(/\[(.*?)\]/, '')
        StatsD.increment STATSD_VALIDATION_FAIL_TYPE_KEY, tags: [key: key]
      end
    end
  end
end
