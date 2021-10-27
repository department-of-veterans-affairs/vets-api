# frozen_string_literal: true

require 'caseflow/service'
require 'common/exceptions'
require 'appeals_api/form_schemas'

class AppealsApi::V2::DecisionReviews::LegacyAppealsController < AppealsApi::ApplicationController
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
    HEADERS.index_with { |key| request.headers[key] }.compact
  end

  def validate_json_schema
    validate_json_schema_for_headers
  end

  def validate_json_schema_for_headers
    AppealsApi::FormSchemas.new(
      SCHEMA_ERROR_TYPE,
      schema_version: 'v2'
    ).validate!('LEGACY_APPEALS_HEADERS', request_headers)
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
    render json: UNUSABLE_RESPONSE_ERROR, status: UNUSABLE_RESPONSE_ERROR[:errors].first[:status]
  end
end
