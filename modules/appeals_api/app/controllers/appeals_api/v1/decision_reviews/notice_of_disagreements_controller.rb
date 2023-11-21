# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'appeals_api/form_schemas'

class AppealsApi::V1::DecisionReviews::NoticeOfDisagreementsController < AppealsApi::ApplicationController
  include AppealsApi::JsonFormatValidation
  include AppealsApi::StatusSimulation
  include AppealsApi::CharacterUtilities
  include AppealsApi::HeaderModification
  include AppealsApi::Schemas

  skip_before_action :authenticate
  before_action :validate_json_format, if: -> { request.post? }
  before_action :validate_json_schema, only: %i[create validate]
  before_action :new_notice_of_disagreement, only: %i[create validate]
  before_action :find_notice_of_disagreement, only: %i[show]

  SCHEMA_OPTIONS = { schema_version: 'v1', api_name: 'decision_reviews' }.freeze
  FORM_NUMBER = '10182'
  MODEL_ERROR_STATUS = 422

  def create
    deprecate_headers

    @notice_of_disagreement.save

    # PDF and API versioning are not 1:1, but are closely coupled and in this case are the same
    pdf_version = api_version
    AppealsApi::PdfSubmitJob.perform_async(@notice_of_disagreement.id, 'AppealsApi::NoticeOfDisagreement', pdf_version)
    render_notice_of_disagreement
  end

  def show
    deprecate_headers

    @notice_of_disagreement = with_status_simulation(@notice_of_disagreement) if status_requested_and_allowed?
    render_notice_of_disagreement
  end

  def validate
    deprecate_headers

    render json: validation_success
  end

  def schema
    deprecate_headers

    render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(form_schema)
  end

  private

  def header_names = headers_schema['definitions']['nodCreateHeadersRoot']['properties'].keys

  def validate_json_schema
    validate_headers(request_headers)
    validate_form_data(@json_body)
  rescue Common::Exceptions::DetailedSchemaErrors => e
    render json: { errors: e.errors }, status: :unprocessable_entity
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
    header_names.index_with { |key| request.headers[key] }.compact
  end

  def new_notice_of_disagreement
    @notice_of_disagreement = AppealsApi::NoticeOfDisagreement.new(
      auth_headers: request_headers,
      form_data: @json_body,
      source: request_headers['X-Consumer-Username'],
      board_review_option: @json_body['data']['attributes']['boardReviewOption'],
      api_version:,
      veteran_icn: request_headers['X-VA-ICN'].presence&.strip
    )
    render_model_errors unless @notice_of_disagreement.validate
  end

  def api_version
    if request.fullpath.include?('v1')
      'V1'
    elsif request.fullpath.include?('v2')
      'V2'
    end
  end

  # Follows JSON API v1.0 error object standard (https://jsonapi.org/format/1.0/#error-objects)
  def render_model_errors
    render json: model_errors_to_json_api(@notice_of_disagreement), status: MODEL_ERROR_STATUS
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

  def deprecate_headers
    deprecate(response:)
  end
end
