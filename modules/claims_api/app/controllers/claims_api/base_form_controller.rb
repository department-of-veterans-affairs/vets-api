# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'
require_dependency 'claims_api/json_api_missing_attribute'

module ClaimsApi
  class BaseFormController < ClaimsApi::ApplicationController
    before_action :validate_json_schema

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
