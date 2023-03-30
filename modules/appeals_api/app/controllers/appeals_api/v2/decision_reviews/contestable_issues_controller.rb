# frozen_string_literal: true

require 'caseflow/service'
require 'common/exceptions'
require 'appeals_api/form_schemas'

module AppealsApi::V2
  module DecisionReviews
    class ContestableIssuesController < AppealsApi::ApplicationController
      FORM_NUMBER = 'CONTESTABLE_ISSUES_HEADERS'
      HEADERS = JSON.parse(
        File.read(
          AppealsApi::Engine.root.join('config/schemas/v2/contestable_issues_headers.json')
        )
      )['definitions']['contestableIssuesIndexParameters']['properties'].keys
      SCHEMA_ERROR_TYPE = Common::Exceptions::DetailedSchemaErrors
      skip_before_action :authenticate
      before_action :validate_json_schema, only: %i[index]
      before_action :validate_params, only: %i[index]

      VALID_DECISION_REVIEW_TYPES = %w[higher_level_reviews notice_of_disagreements supplemental_claims].freeze

      UNUSABLE_RESPONSE_ERROR = {
        errors: [
          {
            title: 'Bad Gateway',
            code: 'bad_gateway',
            detail: 'Received an unusable response from Caseflow.',
            status: 502
          }
        ]
      }.freeze

      def index
        get_contestable_issues_from_caseflow

        if caseflow_response_has_a_body_and_a_status?
          render_response(caseflow_response)
        else
          render_unusable_response_error
        end
      end

      private

      attr_reader :caseflow_response, :backend_service_exception

      def get_contestable_issues_from_caseflow(filter: true)
        caseflow_response = Caseflow::Service.new.get_contestable_issues(headers: caseflow_request_headers,
                                                                         benefit_type:,
                                                                         decision_review_type:)

        @caseflow_response = filtered_caseflow_response(decision_review_type, caseflow_response, filter)
      rescue Common::Exceptions::BackendServiceException => @backend_service_exception # rubocop:disable Naming/RescuedExceptionsVariableName
        log_caseflow_error 'BackendServiceException',
                           backend_service_exception.original_status,
                           backend_service_exception.original_body

        raise unless caseflow_returned_a_4xx?

        @caseflow_response = caseflow_response_from_backend_service_exception
      end

      def filtered_caseflow_response(decision_review_type, caseflow_response, filter)
        return caseflow_response unless filter
        return caseflow_response unless decision_review_type == 'appeals'
        return caseflow_response if caseflow_response.body['data'].nil?

        caseflow_response.body['data'].reject! do |issue|
          issue['attributes']['ratingIssueSubjectText'].nil?
        end

        caseflow_response.body['data'].sort_by! do |issue|
          Date.strptime(issue['attributes']['approxDecisionDate'], '%Y-%m-%d')
        end

        caseflow_response.body['data'].reverse!

        caseflow_response
      end

      def caseflow_response_has_a_body_and_a_status?
        caseflow_response.try(:status) && caseflow_response.try(:body).is_a?(Hash)
      end

      def caseflow_returned_a_4xx?
        status = Integer backend_service_exception.original_status
        status >= 400 && status < 500
      end

      def caseflow_response_from_backend_service_exception
        # Something in the BackendServiceException chain adds more fields than necessary to the caseflow response body,
        # so filter it only to "errors" when possible.
        body = backend_service_exception.original_body
        filtered_body = body.slice('errors').presence || body
        Struct.new(:status, :body).new(
          backend_service_exception.original_status,
          filtered_body.deep_transform_values(&:to_s)
        )
      end

      def render_unusable_response_error
        log_caseflow_error 'UnusableResponse', caseflow_response.status, caseflow_response.body
        render json: UNUSABLE_RESPONSE_ERROR, status: UNUSABLE_RESPONSE_ERROR[:errors].first[:status]
      end

      def decision_review_type
        if params[:decision_review_type] == 'notice_of_disagreements'
          'appeals'
        else
          params[:decision_review_type]
        end
      end

      def benefit_type
        if params[:decision_review_type] == 'notice_of_disagreements'
          ''
        else
          caseflow_benefit_type_mapping[params[:benefit_type].to_s]
        end
      end

      def validate_params
        if invalid_decision_review_type?
          render_unprocessable_entity(
            "decision_review_type must be one of: #{VALID_DECISION_REVIEW_TYPES.join(', ')}"
          )
        elsif invalid_benefit_type?
          render_unprocessable_entity(
            "benefit_type must be one of: #{caseflow_benefit_type_mapping.keys.join(', ')}"
          )
        end
      end

      def invalid_decision_review_type?
        raw_decision_review_type = params[:decision_review_type]
        !raw_decision_review_type.in?(VALID_DECISION_REVIEW_TYPES)
      end

      def invalid_benefit_type?
        return false if params[:decision_review_type] == 'notice_of_disagreements'

        !params[:benefit_type].in?(caseflow_benefit_type_mapping.keys)
      end

      def render_unprocessable_entity(message)
        render json: {
          errors: [
            {
              title: 'Unprocessable Entity',
              code: 'unprocessable_entity',
              detail: message,
              status: '422'
            }
          ]
        }, status: '422'
      end

      def request_headers
        self.class::HEADERS.index_with { |key| request.headers[key] }.compact
      end

      def caseflow_request_headers
        request_headers.except('X-VA-ICN')
      end

      def validate_json_schema
        validate_json_schema_for_headers
        validate_params
      end

      def validate_json_schema_for_headers
        AppealsApi::FormSchemas.new(
          SCHEMA_ERROR_TYPE,
          schema_version: 'v2'
        ).validate!(self.class::FORM_NUMBER, request_headers)
      end

      def caseflow_benefit_type_mapping
        {
          'compensation' => 'compensation',
          'pensionSurvivorsBenefits' => 'pension',
          'fiduciary' => 'fiduciary',
          'lifeInsurance' => 'insurance',
          'veteransHealthAdministration' => 'vha',
          'veteranReadinessAndEmployment' => 'voc_rehab',
          'loanGuaranty' => 'loan_guaranty',
          'education' => 'education',
          'nationalCemeteryAdministration' => 'nca'
        }
      end

      def log_caseflow_error(error_reason, status, body)
        Rails.logger.error("#{self.class.name} Caseflow::Service error: #{error_reason}", caseflow_status: status,
                                                                                          caseflow_body: body)
      end
    end
  end
end
