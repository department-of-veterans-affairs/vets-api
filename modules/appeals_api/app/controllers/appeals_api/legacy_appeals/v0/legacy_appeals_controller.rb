# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::LegacyAppeals::V0
  class LegacyAppealsController < AppealsApi::V2::DecisionReviews::LegacyAppealsController
    include AppealsApi::Schemas
    include AppealsApi::OpenidAuth

    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'legacy_appeals' }.freeze

    OAUTH_SCOPES = {
      GET: %w[veteran/LegacyAppeals.read representative/LegacyAppeals.read system/LegacyAppeals.read]
    }.freeze

    def schema
      render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(headers_schema)
    end

    private

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :legacy_appeals, :api_key)
    end
  end
end
