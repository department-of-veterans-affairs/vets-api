# frozen_string_literal: true

require 'caseflow/service'
require 'common/exceptions'

class AppealsApi::V1::DecisionReviews::BaseContestableIssuesController < AppealsApi::ApplicationController
  skip_before_action(:authenticate)
  before_action :validate_headers, only: %i[index]

  EXPECTED_HEADERS = %w[X-VA-SSN X-VA-Receipt-Date X-VA-File-Number X-VA-ICN].freeze
  SSN_REGEX = /^[0-9]{9}$/
  ICN_REGEX = /^[0-9]{10}V[0-9]{6}$/
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

  def request_headers
    EXPECTED_HEADERS.index_with { |key| request.headers[key] }.compact
  end

  def caseflow_request_headers
    request_headers.except('X-VA-ICN')
  end

  def get_contestable_issues_from_caseflow(filter: true)
    caseflow_response = Caseflow::Service.new.get_contestable_issues headers: caseflow_request_headers,
                                                                     benefit_type: benefit_type,
                                                                     decision_review_type: decision_review_type

    @caseflow_response = filtered_caseflow_response(decision_review_type, caseflow_response, filter)
  rescue Common::Exceptions::BackendServiceException => @backend_service_exception # rubocop:disable Naming/RescuedExceptionsVariableName
    log_caseflow_error 'BackendServiceException',
                       backend_service_exception.original_status,
                       backend_service_exception.original_body

    raise unless caseflow_returned_a_4xx?

    @caseflow_response = caseflow_response_from_backend_service_exception
  end

  def benefit_type
    params[:benefit_type] || '' # Notice of Disagreements does not use benefit type
  end

  ##
  # Returns the type of appeal, used when retrieving contestable issues from Caseflow
  #
  # @return [String] The appeal type (appeals (nod), higher_level_reviews, etc)
  #
  def decision_review_type
    raise NotImplementedError, 'Subclass of BaseContestableIssuesController must implement decision_review_type method'
  end

  def filtered_caseflow_response(decision_review_type, caseflow_response, filter)
    return caseflow_response unless filter
    return caseflow_response unless decision_review_type == 'appeals' # NOD requires this filtering step, HLR does not
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
    Struct.new(:status, :body).new(
      backend_service_exception.original_status,
      backend_service_exception.original_body
    )
  end

  def render_unusable_response_error
    log_caseflow_error 'UnusableResponse', caseflow_response.status, caseflow_response.body
    render json: UNUSABLE_RESPONSE_ERROR, status: UNUSABLE_RESPONSE_ERROR[:errors].first[:status]
  end

  def validate_headers
    validation_errors = []
    ssn = request.headers['X-VA-SSN']
    icn = request.headers['X-VA-ICN']

    if request.headers['X-VA-Receipt-Date'].nil?
      validation_errors << { status: 422, detail: 'X-VA-Receipt-Date is required' }
    end
    if ssn.nil? && request.headers['X-VA-File-Number'].nil?
      validation_errors << { status: 422, detail: 'X-VA-SSN or X-VA-File-Number is required' }
    end
    if ssn.present? && !SSN_REGEX.match?(ssn)
      validation_errors << { status: 422, detail: "X-VA-SSN has an invalid format. Pattern: #{SSN_REGEX.inspect}" }
    end
    if icn.present? && !ICN_REGEX.match?(icn)
      validation_errors << { status: 422, detail: "X-VA-ICN has an invalid format. Pattern: #{ICN_REGEX.inspect}" }
    end

    render_validation_errors(validation_errors)
  end

  def render_validation_errors(validation_errors)
    return if validation_errors.empty?

    render json: { errors: validation_errors }, status: :unprocessable_entity unless validation_errors.empty?
  end

  def log_caseflow_error(error_reason, status, body)
    Rails.logger.error("#{self.class.name} Caseflow::Service error: #{error_reason}", caseflow_status: status,
                                                                                      caseflow_body: body)
  end
end
