# frozen_string_literal: true

module ClaimsApi
  class BaseDisabilityCompensationController < ClaimsApi::BaseFormController
    STATSD_VALIDATION_FAIL_KEY = 'api.claims_api.526.validation_fail'
    STATSD_VALIDATION_FAIL_TYPE_KEY = 'api.claims_api.526.validation_fail_type'

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
  end
end
