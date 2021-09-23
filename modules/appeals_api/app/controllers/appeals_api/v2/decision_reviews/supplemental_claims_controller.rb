# frozen_string_literal: true

require 'appeals_api/form_schemas'

class AppealsApi::V2::DecisionReviews::SupplementalClaimsController < AppealsApi::ApplicationController
  include AppealsApi::JsonFormatValidation
  # include AppealsApi::StatusSimulation
  include AppealsApi::CharacterUtilities
  include AppealsApi::CharacterValidation

  skip_before_action :authenticate
  before_action :validate_characters, only: %i[create]
  before_action :validate_json_format, if: -> { request.post? }
  before_action :validate_json_schema, only: %i[create]

  FORM_NUMBER = '200995'
  MODEL_ERROR_STATUS = 422
  HEADERS = JSON.parse(
    File.read(
      AppealsApi::Engine.root.join('config/schemas/v2/200995_headers.json')
    )
  )['definitions']['supplementalClaimParams']['properties'].keys
  SCHEMA_ERROR_TYPE = Common::Exceptions::DetailedSchemaErrors

  def create
    sc = AppealsApi::SupplementalClaim.new(
      auth_headers: request_headers,
      form_data: @json_body,
      source: request_headers['X-Consumer-Username'],
      api_version: 'V2'
    )

    render_model_errors(sc) and return unless sc.validate

    sc.save

    render json: AppealsApi::SupplementalClaimSerializer.new(sc).serializable_hash
  end

  def show
    id = params[:id]
    sc = AppealsApi::SupplementalClaim.find(id)

    render json: AppealsApi::SupplementalClaimSerializer.new(sc).serializable_hash
  rescue ActiveRecord::RecordNotFound
    render_supplemental_claim_not_found(id)
  end

  private

  def validate_json_schema
    validate_json_schema_for_headers
    validate_json_schema_for_body
  end

  def validate_json_schema_for_headers
    AppealsApi::FormSchemas.new(
      SCHEMA_ERROR_TYPE,
      schema_version: 'v2'
    ).validate!("#{self.class::FORM_NUMBER}_HEADERS", request_headers)
  end

  def validate_json_schema_for_body
    AppealsApi::FormSchemas.new(
      SCHEMA_ERROR_TYPE,
      schema_version: 'v2'
    ).validate!(self.class::FORM_NUMBER, @json_body)
  end

  def request_headers
    HEADERS.index_with { |key| request.headers[key] }.compact
  end

  def render_model_errors(model)
    render json: model_errors_to_json_api(model), status: MODEL_ERROR_STATUS
  end

  def model_errors_to_json_api(model)
    errors = model.errors.to_a.map do |error|
      { status: MODEL_ERROR_STATUS, detail: error }
    end

    { errors: errors }
  end

  def render_supplemental_claim_not_found(id)
    render(
      status: :not_found,
      json: {
        errors: [
          { status: 404, detail: "SupplementalClaim with uuid #{id.inspect} not found." }
        ]
      }
    )
  end
end
