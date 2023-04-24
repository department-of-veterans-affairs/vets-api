# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'appeals_api/form_schemas'

class AppealsApi::V2::DecisionReviews::NoticeOfDisagreementsController < AppealsApi::ApplicationController
  include AppealsApi::JsonFormatValidation
  include AppealsApi::StatusSimulation
  include AppealsApi::CharacterUtilities

  skip_before_action :authenticate
  before_action :validate_index_headers, only: %i[index]
  before_action :validate_json_format, if: -> { request.post? }
  before_action :validate_json_schema, only: %i[create validate]
  before_action :new_notice_of_disagreement, only: %i[create validate]
  before_action :find_notice_of_disagreement, only: %i[show]

  FORM_NUMBER = '10182'
  API_VERSION = 'V2'
  SCHEMA_VERSION = 'v2'
  MODEL_ERROR_STATUS = 422
  HEADERS = JSON.parse(
    File.read(
      AppealsApi::Engine.root.join('config/schemas/v2/10182_headers.json')
    )
  )['definitions']['nodCreateParameters']['properties'].keys
  SCHEMA_ERROR_TYPE = Common::Exceptions::DetailedSchemaErrors
  ALLOWED_COLUMNS = %i[id status code detail created_at updated_at].freeze
  ICN_HEADER = 'X-VA-ICN'
  ICN_REGEX = /^[0-9]{10}V[0-9]{6}$/

  def index
    veteran_nods = AppealsApi::NoticeOfDisagreement.select(ALLOWED_COLUMNS)
                                                   .where(veteran_icn: request_headers['X-VA-ICN'])
                                                   .order(created_at: :desc)
    render json: AppealsApi::NoticeOfDisagreementSerializer.new(veteran_nods).serializable_hash
  end

  def create
    @notice_of_disagreement.save
    AppealsApi::PdfSubmitJob.perform_async(
      @notice_of_disagreement.id,
      'AppealsApi::NoticeOfDisagreement',
      'v3'
    )
    render_notice_of_disagreement
  end

  def show
    @notice_of_disagreement = with_status_simulation(@notice_of_disagreement) if status_requested_and_allowed?
    render_notice_of_disagreement
  end

  def validate
    render json: validation_success
  end

  def schema
    # TODO: Return full schema after we've validated all Non-Veteran Claimant functionality
    response = AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(
      AppealsApi::FormSchemas.new(
        SCHEMA_ERROR_TYPE,
        schema_version: self.class::SCHEMA_VERSION
      ).schema(self.class::FORM_NUMBER)
    )
    response.tap do |s|
      s.dig(*%w[definitions nodCreate properties data properties attributes properties]).delete('claimant')
    end

    render json: response
  end

  private

  def validate_index_headers
    validation_errors = []

    if request_headers[ICN_HEADER].blank?
      validation_errors << { status: 422, detail: "#{ICN_HEADER} is required" }
    elsif !ICN_REGEX.match?(request_headers[ICN_HEADER])
      validation_errors << { status: 422, detail: "#{ICN_HEADER} has an invalid format. Pattern: #{ICN_REGEX.inspect}" }
    end

    render json: { errors: validation_errors }, status: :unprocessable_entity if validation_errors.present?
  end

  def validate_json_schema
    validate_json_schema_for_headers
    validate_json_schema_for_body
  rescue SCHEMA_ERROR_TYPE => e
    render json: { errors: e.errors }, status: :unprocessable_entity
  end

  def validate_json_schema_for_headers
    AppealsApi::FormSchemas.new(
      SCHEMA_ERROR_TYPE,
      schema_version: self.class::SCHEMA_VERSION
    ).validate!("#{self.class::FORM_NUMBER}_HEADERS", request_headers)
  end

  def validate_json_schema_for_body
    schema = AppealsApi::FormSchemas.new(SCHEMA_ERROR_TYPE, schema_version: self.class::SCHEMA_VERSION)
    schema.validate!(self.class::FORM_NUMBER, @json_body)
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
    self.class::HEADERS.index_with { |key| request.headers[key] }.compact
  end

  def new_notice_of_disagreement
    @notice_of_disagreement = AppealsApi::NoticeOfDisagreement.new(
      auth_headers: request_headers,
      form_data: @json_body,
      source: request_headers['X-Consumer-Username'].presence&.strip,
      board_review_option: @json_body['data']['attributes']['boardReviewOption'],
      api_version: self.class::API_VERSION,
      veteran_icn: request_headers['X-VA-ICN']
    )
    render_model_errors unless @notice_of_disagreement.validate
  end

  # Follows JSON API v1.0 error object standard (https://jsonapi.org/format/1.0/#error-objects)
  def render_model_errors
    render json: model_errors_to_json_api(@notice_of_disagreement), status: MODEL_ERROR_STATUS
  end

  def find_notice_of_disagreement
    @id = params[:id]
    @notice_of_disagreement = AppealsApi::NoticeOfDisagreement.select(ALLOWED_COLUMNS).find(@id)
  rescue ActiveRecord::RecordNotFound
    render_notice_of_disagreement_not_found
  end

  def render_notice_of_disagreement_not_found
    render(
      status: :not_found,
      json: {
        errors: [
          {
            code: '404',
            detail: I18n.t('appeals_api.errors.not_found', type: 'NoticeOfDisagreement', id: @id),
            status: '404',
            title: 'Record not found'
          }
        ]
      }
    )
  end

  def render_notice_of_disagreement
    render json: AppealsApi::NoticeOfDisagreementSerializer.new(@notice_of_disagreement).serializable_hash
  end
end
