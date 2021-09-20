# frozen_string_literal: true

require 'caseflow/service'
require 'common/exceptions'

class AppealsApi::V2::DecisionReviews::LegacyAppealsController < AppealsApi::ApplicationController
  SSN_REGEX = /^[0-9]{9}$/.freeze

  skip_before_action(:authenticate)
  before_action :validate_headers, only: %i[index]

  EXPECTED_HEADERS = %w[X-VA-SSN X-VA-File-Number].freeze

  def index
    get_legacy_appeals_from_caseflow

    if caseflow_response_usable?
      render_response(caseflow_response)
    else
      render_unusable_response_error
    end
  end

  private

  attr_reader :caseflow_response, :caseflow_exception_response

  def request_headers
    EXPECTED_HEADERS.index_with { |key| request.headers[key] }.compact
  end

  def validate_headers
    validation_errors = []
    ssn = request.headers['X-VA-SSN']
    file_number = request.headers['X-VA-File-Number']

    if ssn.blank? && file_number.blank?
      validation_errors << { status: 422, detail: 'X-VA-SSN or X-VA-File-Number is required' }
    end

    if ssn.present? && !SSN_REGEX.match?(ssn)
      validation_errors << { status: 422, detail: "X-VA-SSN has an invalid format. Pattern: #{SSN_REGEX.inspect}" }
    end

    render_validation_errors(validation_errors)
  end

  def render_validation_errors(validation_errors)
    return if validation_errors.empty?

    render json: { errors: validation_errors }, status: :unprocessable_entity
  end

  def get_legacy_appeals_from_caseflow
    @caseflow_response = Caseflow::Service.new.get_legacy_appeals headers: request_headers
  rescue Common::Exceptions::BackendServiceException => @caseflow_exception_response # rubocop:disable Naming/RescuedExceptionsVariableName
    raise unless caseflow_returned_a_4xx?

    @caseflow_response = caseflow_exception
  end

  def caseflow_response_usable?
    caseflow_response.try(:status) && caseflow_response.try(:body).is_a?(Hash)
  end

  def caseflow_returned_a_4xx?
    status = Integer caseflow_exception_response.original_status
    status.between?(400, 499)
  end

  def caseflow_exception
    Struct.new(:status, :body).new(
      caseflow_exception_response.original_status,
      caseflow_exception_response.original_body
    )
  end

  def render_unusable_response_error
    # Status is both rendered and updated -> an unusable response from Caseflow will have returned with a status: 200
    render status: :bad_gateway,
           json: Common::Exceptions::BackendServiceException.new(detail: 'Unusable upstream response')
  end
end
