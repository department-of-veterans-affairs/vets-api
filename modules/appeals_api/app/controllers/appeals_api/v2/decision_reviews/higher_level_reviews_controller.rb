# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'appeals_api/form_schemas'

class AppealsApi::V2::DecisionReviews::HigherLevelReviewsController < AppealsApi::ApplicationController
  include AppealsApi::JsonFormatValidation
  include AppealsApi::StatusSimulation
  include AppealsApi::CharacterUtilities
  include AppealsApi::MPIVeteran
  include AppealsApi::Schemas
  include AppealsApi::PdfDownloads

  skip_before_action :authenticate
  before_action :validate_icn_header, only: %i[index download]
  before_action :validate_json_format, if: -> { request.post? }
  before_action :validate_json_schema, only: %i[create validate]
  before_action :new_higher_level_review, only: %i[create validate]
  before_action :find_higher_level_review, only: %i[show]

  FORM_NUMBER = '200996'
  API_VERSION = 'V2'
  MODEL_ERROR_STATUS = 422
  SCHEMA_OPTIONS = { schema_version: 'v2', api_name: 'decision_reviews' }.freeze
  ALLOWED_COLUMNS = %i[id status code detail created_at updated_at].freeze
  ICN_HEADER = 'X-VA-ICN'
  ICN_REGEX = /^[0-9]{10}V[0-9]{6}$/

  def index
    veteran_hlrs = AppealsApi::HigherLevelReview.select(ALLOWED_COLUMNS)
                                                .where(veteran_icn: request_headers['X-VA-ICN'])
                                                .order(created_at: :desc)
    render json: AppealsApi::HigherLevelReviewSerializer.new(veteran_hlrs).serializable_hash
  end

  def create
    @higher_level_review.save
    pdf_version = Flipper.enabled?(:decision_review_higher_level_review_pdf_v3) ? 'v3' : 'v2'
    AppealsApi::PdfSubmitJob.perform_async(@higher_level_review.id, 'AppealsApi::HigherLevelReview', pdf_version)
    if @higher_level_review.veteran_icn.blank?
      AppealsApi::AddIcnUpdater.perform_async(@higher_level_review.id, 'AppealsApi::HigherLevelReview')
    end

    render_higher_level_review
  end

  def validate
    render json: validation_success
  end

  def schema
    render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(form_schema)
  end

  def show
    @higher_level_review = with_status_simulation(@higher_level_review) if status_requested_and_allowed?
    render_higher_level_review
  end

  def download
    @id = params[:id]
    @higher_level_review = AppealsApi::HigherLevelReview.find(@id)

    render_appeal_pdf_download(
      @higher_level_review,
      "#{FORM_NUMBER}-higher-level-review-#{@id}.pdf",
      request_headers['X-VA-ICN']
    )
  rescue ActiveRecord::RecordNotFound
    render_higher_level_review_not_found
  end

  private

  def header_names = headers_schema['definitions']['hlrCreateParameters']['properties'].keys

  def validate_icn_header
    detail = nil

    if request_headers[ICN_HEADER].blank?
      detail = "#{ICN_HEADER} is required"
    elsif !ICN_REGEX.match?(request_headers[ICN_HEADER])
      detail = "#{ICN_HEADER} has an invalid format. Pattern: #{ICN_REGEX.inspect}"
    end

    raise Common::Exceptions::UnprocessableEntity.new(detail:) if detail.present?
  end

  def validate_json_schema
    validate_headers(request_headers)
    validate_form_data(@json_body)
    validate_json_schema_for_pdf_fit
  rescue JsonSchema::JsonApiMissingAttribute => e
    render json: e.to_json_api, status: e.code
  end

  def validate_json_schema_for_pdf_fit
    status, error = AppealsApi::HigherLevelReviews::PdfFormFieldV2Validator.new(
      @json_body,
      headers
    ).validate!

    return if error.blank?

    render status:, json: error
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
    header_names.index_with { |key| request.headers[key] }.compact
  end

  def new_higher_level_review
    @higher_level_review = AppealsApi::HigherLevelReview.new(
      auth_headers: request_headers,
      form_data: @json_body,
      source: request_headers['X-Consumer-Username'].presence&.strip,
      api_version: self.class::API_VERSION,
      veteran_icn: request_headers['X-VA-ICN']
    )

    render_model_errors unless @higher_level_review.validate
  end

  def render_model_errors
    render json: model_errors_to_json_api(@higher_level_review), status: MODEL_ERROR_STATUS
  end

  def find_higher_level_review
    @id = params[:id]
    @higher_level_review = AppealsApi::HigherLevelReview.select(ALLOWED_COLUMNS).find(@id)
  rescue ActiveRecord::RecordNotFound
    render_higher_level_review_not_found
  end

  def render_higher_level_review_not_found
    render(
      status: :not_found,
      json: {
        errors: [
          {
            code: '404',
            detail: I18n.t('appeals_api.errors.not_found', type: 'HigherLevelReview', id: @id),
            status: '404',
            title: 'Record not found'
          }
        ]
      }
    )
  end

  def render_higher_level_review
    render json: AppealsApi::HigherLevelReviewSerializer.new(@higher_level_review).serializable_hash
  end
end
