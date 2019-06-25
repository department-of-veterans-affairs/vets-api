# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'
require_dependency 'claims_api/json_api_missing_attribute'

module ClaimsApi
  class BaseFormController < ClaimsApi::ApplicationController
    before_action :validate_json_schema

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
      unless itf_service.get_active('compensation')['intent_to_file'].expiration_date > Time.now.utc
        error = {
          errors: [
            {
              status: 422,
              details: 'Intent to File Expiration Date has expired, please resubmit ITF.'
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
  end
end
