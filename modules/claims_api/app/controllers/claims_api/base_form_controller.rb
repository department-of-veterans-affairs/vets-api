# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'
require_dependency 'claims_api/json_api_missing_attribute'

module ClaimsApi
  class BaseFormController < ClaimsApi::ApplicationController
    # schema endpoint should be wide open
    skip_before_action :authenticate, only: %i[schema]
    skip_before_action :verify_mvi, only: %i[schema]

    def schema
      render json: { data: [ClaimsApi::FormSchemas::SCHEMAS[self.class::FORM_NUMBER]] }
    end

    private

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
