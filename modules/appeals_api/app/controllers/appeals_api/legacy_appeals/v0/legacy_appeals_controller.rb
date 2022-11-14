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

    def schema
      render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(
        AppealsApi::FormSchemas.new(
          SCHEMA_ERROR_TYPE,
          schema_version: 'v2'
        ).schema(self.class::FORM_NUMBER)
      )
    end
  end
end
