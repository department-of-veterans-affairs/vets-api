# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::AppealableIssues::V0
  class AppealableIssuesController < AppealsApi::V2::DecisionReviews::ContestableIssuesController
    include AppealsApi::OpenidAuth

    FORM_NUMBER = 'CONTESTABLE_ISSUES_HEADERS_WITH_SHARED_REFS'
    HEADERS = JSON.parse(
      File.read(
        AppealsApi::Engine.root.join('config/schemas/v2/contestable_issues_headers_with_shared_refs.json')
      )
    )['definitions']['contestableIssuesIndexParameters']['properties'].keys

    OAUTH_SCOPES = {
      GET: %w[
        veteran/AppealableIssues.read representative/AppealableIssues.read system/AppealableIssues.read
        veteran/ContestableIssues.read representative/ContestableIssues.read system/ContestableIssues.read
      ]
    }.freeze

    def schema
      render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(
        AppealsApi::FormSchemas.new(
          SCHEMA_ERROR_TYPE,
          schema_version: 'v2'
        ).schema(self.class::FORM_NUMBER)
      )
    end

    private

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :contestable_issues, :api_key)
    end
  end
end
