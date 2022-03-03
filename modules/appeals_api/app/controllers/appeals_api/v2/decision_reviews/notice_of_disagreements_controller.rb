# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'appeals_api/form_schemas'

class AppealsApi::V2::DecisionReviews::NoticeOfDisagreementsController < AppealsApi::ApplicationController
  include AppealsApi::JsonFormatValidation
  include AppealsApi::StatusSimulation
  include AppealsApi::CharacterUtilities
  include AppealsApi::CharacterValidation

  skip_before_action :authenticate
  before_action :validate_characters, only: %i[create] # TODO: add back validate in next PR
  before_action :validate_json_format, if: -> { request.post? }
  before_action :validate_json_schema, only: %i[create] # TODO: add back validate in next PR
  before_action :new_notice_of_disagreement, only: %i[create] # TODO: add back validate in next PR
  # before_action :find_notice_of_disagreement, only: %i[show] # TODO: uncomment in next PR
  # TODO: in next PR - validate extension request == true if extension reason provided

  FORM_NUMBER = '10182'
  MODEL_ERROR_STATUS = 422
  HEADERS = JSON.parse(
    File.read(
      AppealsApi::Engine.root.join('config/schemas/v2/10182_headers.json')
    )
  )['definitions']['nodCreateHeaders']['properties'].keys
  SCHEMA_ERROR_TYPE = Common::Exceptions::DetailedSchemaErrors

  def create
    @notice_of_disagreement.save
    render_notice_of_disagreement
  end

  private

  def validate_json_schema
    validate_json_schema_for_headers
    validate_json_schema_for_body
  rescue SCHEMA_ERROR_TYPE => e
    render json: { errors: e.errors }, status: :unprocessable_entity
  end

  def validate_json_schema_for_headers
    AppealsApi::FormSchemas.new(
      SCHEMA_ERROR_TYPE,
      schema_version: 'v2'
    ).validate!("#{FORM_NUMBER}_HEADERS", request_headers)
  end

  def validate_json_schema_for_body
    AppealsApi::FormSchemas.new(SCHEMA_ERROR_TYPE, schema_version: 'v2').validate!(FORM_NUMBER, @json_body)
  end

  def validation_success
    {
      data: {
        type: 'noticeOfDisagreementValidation',
        attributes: {
          status: 'valid'
        }
      }
    }
  end

  def request_headers
    HEADERS.index_with { |key| request.headers[key] }.compact
  end

  def new_notice_of_disagreement
    @notice_of_disagreement = AppealsApi::NoticeOfDisagreement.new(
      auth_headers: request_headers,
      form_data: @json_body,
      source: request_headers['X-Consumer-Username'],
      board_review_option: @json_body['data']['attributes']['boardReviewOption'],
      api_version: 'v2'
    )
  end

  # Follows JSON API v1.0 error object standard (https://jsonapi.org/format/1.0/#error-objects)
  def render_model_errors
    render json: model_errors_to_json_api, status: MODEL_ERROR_STATUS
  end

  def model_errors_to_json_api
    errors = @notice_of_disagreement.errors.map do |error|
      data = I18n.t('common.exceptions.validation_errors').deep_merge error.options
      data[:source] = { pointer: error.attribute.to_s }
      data
    end
    { errors: errors }
  end

  def find_notice_of_disagreement
    @id = params[:id]
    @notice_of_disagreement = AppealsApi::NoticeOfDisagreement.find(@id)
  rescue ActiveRecord::RecordNotFound
    render_notice_of_disagreement_not_found
  end

  def render_notice_of_disagreement_not_found
    render(
      status: :not_found,
      json: {
        errors: [
          { status: 404, detail: I18n.t('appeals_api.errors.not_found', type: 'NoticeOfDisagreement', id: @id) }
        ]
      }
    )
  end

  def render_notice_of_disagreement
    render json: AppealsApi::NoticeOfDisagreementSerializer.new(@notice_of_disagreement).serializable_hash
  end
end
