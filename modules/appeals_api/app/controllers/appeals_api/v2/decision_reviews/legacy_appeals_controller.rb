# frozen_string_literal: true

require 'caseflow/service'
require 'common/exceptions'
require 'appeals_api/form_schemas'

class AppealsApi::V2::DecisionReviews::LegacyAppealsController < AppealsApi::ApplicationController
  FORM_NUMBER = 'LEGACY_APPEALS_HEADERS'
  HEADERS = JSON.parse(
    File.read(
      AppealsApi::Engine.root.join('config/schemas/v2/legacy_appeals_headers.json')
    )
  )['definitions']['legacyAppealsIndexParameters']['properties'].keys
  SCHEMA_ERROR_TYPE = Common::Exceptions::DetailedSchemaErrors

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

  skip_before_action :authenticate
  before_action :validate_json_schema, only: %i[index]

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
    self.class::HEADERS.index_with { |key| request.headers[key] }.compact
  end

  def caseflow_request_headers
    request_headers.except('X-VA-ICN')
  end

  def validate_json_schema
    validate_json_schema_for_headers
  end

  def validate_json_schema_for_headers
    AppealsApi::FormSchemas.new(
      SCHEMA_ERROR_TYPE,
      schema_version: 'v2'
    ).validate!(self.class::FORM_NUMBER, request_headers)
  end

  def get_legacy_appeals_from_caseflow
    @caseflow_response = Caseflow::Service.new.get_legacy_appeals headers: caseflow_request_headers
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
    # Something in the BackendServiceException chain adds more fields than necessary to the caseflow response body,
    # so filter it only to "errors" when possible.
    body = caseflow_exception_response.original_body
    filtered_body = body.slice('errors').presence || body
    Struct.new(:status, :body).new(
      caseflow_exception_response.original_status,
      filtered_body.deep_transform_values(&:to_s)
    )
  end

  def render_unusable_response_error
    render json: UNUSABLE_RESPONSE_ERROR, status: UNUSABLE_RESPONSE_ERROR[:errors].first[:status]
  end
end
