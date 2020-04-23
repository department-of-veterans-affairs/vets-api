# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'appeals_api/form_schemas'
require_dependency 'appeals_api/concerns/json_format_validation'

class AppealsApi::V1::DecisionReview::HigherLevelReviewsController < AppealsApi::ApplicationController
  include AppealsApi::JsonFormatValidation

  skip_before_action(:authenticate)
  before_action :validate_json_format, if: -> { request.post? }
  before_action :validate_json_schema, only: %i[create validate]
  before_action :new_higher_level_review, only: %i[create validate]

  FORM_NUMBER = '200996'
  MODEL_ERROR_STATUS = 422
  HEADERS = JSON.parse(
    File.read(
      AppealsApi::Engine.root.join('config/schemas/200996_headers.json')
    )
  )['properties'].keys

  def create
    @higher_level_review.save
    AppealsApi::HigherLevelReviewPdfSubmitJob.perform_async(@higher_level_review.id)
    render json: @higher_level_review, serializer: AppealsApi::HigherLevelReviewSerializer
  end

  def validate
    render json: validation_success
  end

  def schema
    render json: { data: [AppealsApi::FormSchemas.new.schemas[self.class::FORM_NUMBER]] }
  end

  private

  def validate_json_schema
    validate_json_schema_for_headers
    validate_json_schema_for_body
  rescue JsonSchema::JsonApiMissingAttribute => e
    render json: e.to_json_api, status: e.code
  end

  def validate_json_schema_for_headers
    AppealsApi::FormSchemas.new.validate!("#{self.class::FORM_NUMBER}_HEADERS", headers)
  end

  def validate_json_schema_for_body
    AppealsApi::FormSchemas.new.validate!(self.class::FORM_NUMBER, @json_body)
  end

  def validation_success
    {
      data: {
        type: 'appeals_api_higher_level_review_validation',
        attributes: {
          status: 'valid'
        }
      }
    }
  end

  def headers
    HEADERS.reduce({}) do |hash, key|
      hash.merge({ key => request.headers[key] })
    end
  end

  def new_higher_level_review
    @higher_level_review = AppealsApi::HigherLevelReview.new(
      auth_headers: headers, form_data: @json_body
    )

    render_model_errors unless @higher_level_review.validate
  end

  def render_model_errors
    render json: model_errors_to_json_api, status: MODEL_ERROR_STATUS
  end

  def model_errors_to_json_api
    errors = @higher_level_review.errors.to_a.map do |error|
      { status: MODEL_ERROR_STATUS, detail: error }
    end

    { errors: errors }
  end
end
