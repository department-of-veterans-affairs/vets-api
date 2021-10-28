# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'appeals_api/form_schemas'

class AppealsApi::V1::DecisionReviews::HigherLevelReviewsController < AppealsApi::ApplicationController
  include AppealsApi::JsonFormatValidation
  include AppealsApi::StatusSimulation
  include AppealsApi::HeaderModification

  skip_before_action(:authenticate)
  before_action :validate_json_format, if: -> { request.post? }
  before_action :validate_json_schema, only: %i[create validate]
  before_action :new_higher_level_review, only: %i[create validate]
  before_action :find_higher_level_review, only: %i[show]

  FORM_NUMBER = '200996'
  MODEL_ERROR_STATUS = 422
  HEADERS = JSON.parse(
    File.read(
      AppealsApi::Engine.root.join('config/schemas/v1/200996_headers.json')
    )
  )['definitions']['hlrCreateParameters']['properties'].keys

  def create
    deprecate_headers

    @higher_level_review.save
    AppealsApi::PdfSubmitJob.perform_async(@higher_level_review.id, 'AppealsApi::HigherLevelReview')
    render_higher_level_review
  end

  def validate
    deprecate_headers
    render json: validation_success
  end

  def schema
    deprecate_headers
    render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(
      AppealsApi::FormSchemas.new.schema(self.class::FORM_NUMBER)
    )
  end

  def show
    deprecate_headers
    @higher_level_review = with_status_simulation(@higher_level_review) if status_requested_and_allowed?
    render_higher_level_review
  end

  private

  def validate_json_schema
    validate_json_schema_for_headers
    validate_json_schema_for_body
    validate_json_schema_for_pdf_fit
  rescue JsonSchema::JsonApiMissingAttribute => e
    render json: e.to_json_api, status: e.code
  end

  def validate_json_schema_for_headers
    AppealsApi::FormSchemas.new.validate!("#{self.class::FORM_NUMBER}_HEADERS", request_headers)
  end

  def validate_json_schema_for_body
    AppealsApi::FormSchemas.new.validate!(self.class::FORM_NUMBER, @json_body)
  end

  def validate_json_schema_for_pdf_fit
    status, error = AppealsApi::HigherLevelReviews::PdfFormFieldV1Validator.new(
      @json_body,
      headers
    ).validate!

    return if error.blank?

    render status: status, json: error
  end

  def validation_success
    {
      data: {
        type: 'higherLevelReviewValidation',
        attributes: {
          status: 'valid'
        }
      }
    }
  end

  def request_headers
    HEADERS.reduce({}) do |acc, header_key|
      header_value = request.headers[header_key]

      header_value.nil? ? acc : acc.merge({ header_key => header_value })
    end
  end

  def new_higher_level_review
    @higher_level_review = AppealsApi::HigherLevelReview.new(
      auth_headers: request_headers,
      form_data: @json_body,
      source: request_headers['X-Consumer-Username'],
      api_version: 'V1'
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

  def find_higher_level_review
    @id = params[:id]
    @higher_level_review = AppealsApi::HigherLevelReview.find(@id)
  rescue ActiveRecord::RecordNotFound
    render_higher_level_review_not_found
  end

  def render_higher_level_review_not_found
    render(
      status: :not_found,
      json: {
        errors: [
          { status: 404, detail: "HigherLevelReview with uuid #{@id.inspect} not found." }
        ]
      }
    )
  end

  def render_higher_level_review
    render json: AppealsApi::HigherLevelReviewSerializer.new(@higher_level_review).serializable_hash
  end

  def sunset_date
    Date.new(2022, 1, 31)
  end

  def deprecate_headers
    deprecate(response: response, link: AppealsApi::HeaderModification::RELEASE_NOTES_LINK, sunset: sunset_date)
  end
end
