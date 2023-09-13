# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::AppealableIssues::V0
  class AppealableIssuesController < AppealsApi::ApplicationController
    include AppealsApi::CaseflowRequest
    include AppealsApi::OpenidAuth
    include AppealsApi::Schemas

    skip_before_action :authenticate
    before_action :validate_json_schema, only: %i[index]

    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'appealable_issues' }.freeze

    OAUTH_SCOPES = {
      GET: %w[veteran/AppealableIssues.read representative/AppealableIssues.read system/AppealableIssues.read]
    }.freeze

    def index
      render json: caseflow_response.body, status: caseflow_response.status
    end

    def schema
      render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(form_schemas.schema('PARAMS'))
    end

    private

    def header_names = headers_schema['definitions']['appealableIssuesIndexParameters']['properties'].keys

    def request_headers
      header_names.index_with { |key| request.headers[key] }.compact
    end

    def validate_json_schema
      form_schemas.validate!('PARAMS', params.to_unsafe_h)
    end

    def token_validation_api_key
      # FIXME: rename token storage key
      Settings.dig(:modules_appeals_api, :token_validation, :contestable_issues, :api_key)
    end

    def get_caseflow_response
      headers = generate_caseflow_headers
      decision_review_type = if params[:decisionReviewType] == 'notice-of-disagreements'
                               'appeals'
                             else
                               params[:decisionReviewType].to_s.underscore
                             end
      benefit_type = if params[:decisionReviewType] == 'notice-of-disagreements'
                       ''
                     else
                       params[:benefitType].to_s.underscore
                     end

      format_caseflow_response(
        decision_review_type,
        caseflow_service.get_contestable_issues(headers:, decision_review_type:, benefit_type:)
      )
    end

    def generate_caseflow_headers
      { 'X-VA-Receipt-Date' => params[:receiptDate], 'X-VA-SSN' => icn_to_ssn!(params[:icn]) }
    end

    # Filters and reformats a response from caseflow for presentation to the client
    def format_caseflow_response(decision_review_type, res)
      return res unless decision_review_type == 'appeals'
      return res if res.body['data'].nil?

      res.body['data'].reject! { |issue| issue['attributes']['ratingIssueSubjectText'].nil? }
      res.body['data'].sort_by! { |issue| Date.strptime(issue['attributes']['approxDecisionDate'], '%Y-%m-%d') }
      res.body['data'].reverse!

      if res&.body.is_a? Hash
        res.body.fetch('data', []).each do |issue|
          # Responses from caseflow still have the older name 'contestableIssue'
          issue['type'] = 'appealableIssue' if issue['type'] == 'contestableIssue'
        end
      end

      res
    end
  end
end
