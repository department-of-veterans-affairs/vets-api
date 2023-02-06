# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::NoticeOfDisagreements::V0
  class NoticeOfDisagreementsController < AppealsApi::V2::DecisionReviews::NoticeOfDisagreementsController
    include AppealsApi::OpenidAuth

    FORM_NUMBER = '10182_WITH_SHARED_REFS'
    HEADERS = JSON.parse(
      File.read(
        AppealsApi::Engine.root.join('config/schemas/v2/10182_with_shared_refs_headers.json')
      )
    )['definitions']['nodCreateParameters']['properties'].keys

    OAUTH_SCOPES = {
      GET: %w[appeals/NoticeOfDisagreements.read],
      PUT: %w[appeals/NoticeOfDisagreements.write],
      POST: %w[appeals/NoticeOfDisagreements.write]
    }.freeze

    def schema
      response = AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(
        AppealsApi::FormSchemas.new(
          SCHEMA_ERROR_TYPE,
          schema_version: 'v2'
        ).schema(self.class::FORM_NUMBER)
      )

      render json: response
    end

    private

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :notice_of_disagreements, :api_key)
    end
  end
end
