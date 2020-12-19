# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'appeals_api/form_schemas'

class AppealsApi::V1::DecisionReviews::NoticeOfDisagreementsController < AppealsApi::ApplicationController
  include AppealsApi::JsonFormatValidation

  skip_before_action(:authenticate)
  before_action :validate_json_format, if: -> { request.post? }
  before_action :validate_json_schema, only: %i[create validate]
  before_action :new_notice_of_disagreement, only: %i[create validate]
  before_action :find_notice_of_disagreement, only: %i[show]

  FORM_NUMBER = '10182'
  MODEL_ERROR_STATUS = 422
  HEADERS = JSON.parse(
    File.read(
      AppealsApi::Engine.root.join('config/schemas/10182_headers.json')
    )
  )['definitions']['nodCreateHeadersRoot']['properties'].keys
  SCHEMA_ERROR_TYPE = Common::Exceptions::DetailedSchemaErrors

  def create
    @notice_of_disagreement.save
    AppealsApi::NoticeOfDisagreementPdfSubmitJob.perform_async(@notice_of_disagreement.id)
    render_notice_of_disagreement
  end

  def show
    render_notice_of_disagreement
  end

  def validate
    render json: validation_success
  end

  def schema
    render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(
      AppealsApi::FormSchemas.new.schema(self.class::FORM_NUMBER)
    )
  end

  private

  def validate_json_schema
    validate_json_schema_for_headers
    validate_json_schema_for_body
  rescue SCHEMA_ERROR_TYPE => e
    render json: { errors: e.errors }, status: 422
  end

  def validate_json_schema_for_headers
    AppealsApi::FormSchemas.new(SCHEMA_ERROR_TYPE).validate!("#{FORM_NUMBER}_HEADERS", headers)
  end

  def validate_json_schema_for_body
    AppealsApi::FormSchemas.new(SCHEMA_ERROR_TYPE).validate!(FORM_NUMBER, @json_body)
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

  def headers
    HEADERS.reduce({}) do |hash, key|
      hash.merge(key => request.headers[key])
    end.compact
  end

  def new_notice_of_disagreement
    @notice_of_disagreement = AppealsApi::NoticeOfDisagreement.new(auth_headers: headers, form_data: @json_body)
    render_model_errors unless @notice_of_disagreement.validate
  end

  # Follows JSON API v1.0 error object standard (https://jsonapi.org/format/1.0/#error-objects)
  def render_model_errors
    render json: model_errors_to_json_api, status: MODEL_ERROR_STATUS
  end

  def model_errors_to_json_api
    errors = @notice_of_disagreement.errors.to_h.map do |source, data|
      data = I18n.t('common.exceptions.validation_errors').deep_merge data
      data[:source] = { pointer: source.to_s }
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
          { status: 404, detail: I18n.t('appeals_api.errors.nod_not_found', id: @id) }
        ]
      }
    )
  end

  def render_notice_of_disagreement
    render json: AppealsApi::NoticeOfDisagreementSerializer.new(@notice_of_disagreement).serializable_hash
  end
end
