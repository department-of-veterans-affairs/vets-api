# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::AppealableIssues::V0
  class AppealableIssuesController < AppealsApi::V2::DecisionReviews::ContestableIssuesController
    include AppealsApi::OpenidAuth
    include AppealsApi::Schemas

    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'appealable_issues' }.freeze

    OAUTH_SCOPES = {
      GET: %w[veteran/AppealableIssues.read representative/AppealableIssues.read system/AppealableIssues.read]
    }.freeze

    def schema
      render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(headers_schema)
    end

    private

    def header_names = headers_schema['definitions']['appealableIssuesIndexParameters']['properties'].keys

    def token_validation_api_key
      # FIXME: rename token storage key
      Settings.dig(:modules_appeals_api, :token_validation, :contestable_issues, :api_key)
    end

    def filtered_caseflow_response(decision_review_type, caseflow_response, filter)
      super

      if caseflow_response&.body.is_a? Hash
        caseflow_response.body.fetch('data', []).each do |issue|
          # Responses from caseflow still have the older name 'contestableIssue'
          issue['type'] = 'appealableIssue' if issue['type'] == 'contestableIssue'
        end
      end

      caseflow_response
    end
  end
end
