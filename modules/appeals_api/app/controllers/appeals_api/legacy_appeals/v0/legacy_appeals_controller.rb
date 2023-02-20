# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::LegacyAppeals::V0
  class LegacyAppealsController < AppealsApi::V2::DecisionReviews::LegacyAppealsController
    include AppealsApi::OpenidAuth

    FORM_NUMBER = 'LEGACY_APPEALS_HEADERS_WITH_SHARED_REFS'
    HEADERS = JSON.parse(
      File.read(
        AppealsApi::Engine.root.join('config/schemas/v2/legacy_appeals_headers_with_shared_refs.json')
      )
    )['definitions']['legacyAppealsIndexParameters']['properties'].keys

    OAUTH_SCOPES = { GET: %w[appeals/LegacyAppeals.read] }.freeze

    def schema
      render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(
        form_schema.schema(self.class::FORM_NUMBER)
      )
    end

    private

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :legacy_appeals, :api_key)
    end

    def form_schema
      @form_schema ||= AppealsApi::FormSchemas.new(
        SCHEMA_ERROR_TYPE,
        schema_version: 'v2'
      )
    end

    def request_headers
      self.class::HEADERS.index_with { |key| request.headers[key] }.compact
    end

    def validate_json_schema_for_headers
      form_schema.validate!(self.class::FORM_NUMBER, request_headers)
    end
  end
end
