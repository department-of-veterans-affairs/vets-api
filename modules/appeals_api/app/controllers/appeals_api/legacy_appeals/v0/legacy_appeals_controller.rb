# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::LegacyAppeals::V0
  class LegacyAppealsController < AppealsApi::ApplicationController
    include AppealsApi::CaseflowRequest
    include AppealsApi::OpenidAuth
    include AppealsApi::IcnParameterValidation
    include AppealsApi::Schemas

    skip_before_action :authenticate
    before_action :validate_icn_parameter!, only: %i[index]
    before_action :validate_json_schema, only: %i[index]

    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'legacy_appeals' }.freeze

    OAUTH_SCOPES = {
      GET: %w[veteran/LegacyAppeals.read representative/LegacyAppeals.read system/LegacyAppeals.read]
    }.freeze

    def index
      render json: caseflow_response.body, status: caseflow_response.status
    end

    def schema
      render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(form_schemas.schema('PARAMS'))
    end

    private

    def validate_json_schema
      form_schemas.validate!('PARAMS', params.to_unsafe_h)
    end

    def get_caseflow_response
      caseflow_service.get_legacy_appeals headers: { 'X-VA-SSN' => icn_to_ssn!(veteran_icn) }
    end

    def token_validation_api_key
      Settings.modules_appeals_api.token_validation.legacy_appeals.api_key
    end
  end
end
