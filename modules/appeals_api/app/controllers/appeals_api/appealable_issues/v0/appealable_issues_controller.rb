# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::AppealableIssues::V0
  class AppealableIssuesController < AppealsApi::V2::DecisionReviews::ContestableIssuesController
    include AppealsApi::OpenidAuth
    include AppealsApi::Schemas

    # This validation happens in #validate_params now; remove this once inheritance relationship is gone:
    skip_before_action :validate_json_schema

    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'appealable_issues' }.freeze

    OAUTH_SCOPES = {
      GET: %w[veteran/AppealableIssues.read representative/AppealableIssues.read system/AppealableIssues.read]
    }.freeze

    def index
      get_appealable_issues_from_caseflow

      if caseflow_response_has_a_body_and_a_status?
        render_response(caseflow_response)
      else
        render_unusable_response_error
      end
    end

    def schema
      render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(form_schemas.schema('PARAMS'))
    end

    private

    def validate_params = form_schemas.validate!('PARAMS', params.to_unsafe_h)

    def token_validation_api_key
      # FIXME: rename token storage key
      Settings.dig(:modules_appeals_api, :token_validation, :contestable_issues, :api_key)
    end

    # rubocop:disable Metrics/MethodLength
    def get_appealable_issues_from_caseflow(filter: true)
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
      @caseflow_response ||= filtered_caseflow_response(
        decision_review_type,
        Caseflow::Service.new.get_contestable_issues(headers:, decision_review_type:, benefit_type:),
        filter
      )
    rescue Common::Exceptions::BackendServiceException => @backend_service_exception # rubocop:disable Naming/RescuedExceptionsVariableName
      log_caseflow_error 'BackendServiceException',
                         backend_service_exception.original_status,
                         backend_service_exception.original_body

      raise unless caseflow_returned_a_4xx?

      @caseflow_response = caseflow_response_from_backend_service_exception
    end
    # rubocop:enable Metrics/MethodLength

    def generate_caseflow_headers
      mpi = MPI::Service.new
      user = mpi.find_profile_by_identifier(identifier: params[:icn], identifier_type: MPI::Constants::ICN)
      { 'X-VA-Receipt-Date' => params[:receiptDate], 'X-VA-SSN' => user.profile.ssn }
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
