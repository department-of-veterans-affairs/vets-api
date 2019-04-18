# frozen_string_literal: true

require 'claims_api/form_schemas'
require 'claims_api/json_api_missing_attribute'
module ClaimsApi
  class BaseFormController < ApplicationController
    before_action :validate_json_schema

    private

    def validate_json_schema
      ClaimsApi::FormSchemas.validate!(self.class::FORM_NUMBER, form_attributes)
    rescue ClaimsApi::JsonApiMissingAttribute => e
      render json: e.to_json_api, status: e.code
    end

    def form_attributes
      if request.body.string.present?
        JSON.parse(request.body.string).dig('data', 'attributes')
      else
        {}
      end
    end
  end
end
