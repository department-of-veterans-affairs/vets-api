# frozen_string_literal: true

require 'caseflow/service'
require 'common/exceptions'

class AppealsApi::V1::DecisionReviews::BaseContestableIssuesController < AppealsApi::ApplicationController
  skip_before_action(:authenticate)

  EXPECTED_HEADERS = %w[X-VA-SSN X-VA-Receipt-Date].freeze

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

  def get_contestable_issues_from_caseflow
    @caseflow_response = Caseflow::Service.new.get_contestable_issues headers: headers,
                                                                      benefit_type: benefit_type,
                                                                      decision_review_type: decision_review_type
  rescue Common::Exceptions::BackendServiceException => @backend_service_exception # rubocop:disable Naming/RescuedExceptionsVariableName
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

  def headers
    EXPECTED_HEADERS.reduce({}) do |hash, key|
      hash.merge(key => request.headers[key])
    end
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
    render json: UNUSABLE_RESPONSE_ERROR, status: UNUSABLE_RESPONSE_ERROR[:errors].first[:status]
  end
end
