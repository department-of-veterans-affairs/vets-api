# frozen_string_literal: true

require 'appeals_api/form_schemas'

class AppealsApi::V2::DecisionReviews::SupplementalClaimsController < AppealsApi::ApplicationController
  include AppealsApi::JsonFormatValidation
  include AppealsApi::StatusSimulation
  include AppealsApi::CharacterUtilities
  include AppealsApi::MPIVeteran

  skip_before_action :authenticate
  before_action :validate_index_headers, only: %i[index]
  before_action :validate_json_format, if: -> { request.post? }
  before_action :validate_json_schema, only: %i[create validate]

  FORM_NUMBER = '200995'
  MODEL_ERROR_STATUS = 422
  HEADERS = JSON.parse(
    File.read(
      AppealsApi::Engine.root.join('config/schemas/v2/200995_headers.json')
    )
  )['definitions']['scCreateParameters']['properties'].keys
  SCHEMA_ERROR_TYPE = Common::Exceptions::DetailedSchemaErrors
  ALLOWED_COLUMNS = %i[id status code detail created_at updated_at].freeze
  ICN_HEADER = 'X-VA-ICN'
  ICN_REGEX = /^[0-9]{10}V[0-9]{6}$/

  def index
    veteran_scs = AppealsApi::SupplementalClaim.select(ALLOWED_COLUMNS)
                                               .where(veteran_icn: request_headers['X-VA-ICN'])
                                               .order(created_at: :desc)
    render json: AppealsApi::SupplementalClaimSerializer.new(veteran_scs).serializable_hash
  end

  def create
    sc = AppealsApi::SupplementalClaim.new(
      auth_headers: request_headers,
      form_data: @json_body,
      source: request_headers['X-Consumer-Username'].presence&.strip,
      evidence_submission_indicated: evidence_submission_indicated?,
      api_version: 'V2',
      veteran_icn: request_headers['X-VA-ICN'],
      metadata: { evidenceType: @json_body.dig(*%w[data attributes evidenceSubmission evidenceType]) }
    )

    render_model_errors(sc) and return unless sc.validate

    sc.save

    pdf_version = Flipper.enabled?(:decision_review_supplemental_claim_pdf_v3) ? 'v3' : 'v2'
    AppealsApi::PdfSubmitJob.perform_async(sc.id, 'AppealsApi::SupplementalClaim', pdf_version)
    AppealsApi::AddIcnUpdater.perform_async(sc.id, 'AppealsApi::SupplementalClaim') if sc.veteran_icn.blank?

    render json: AppealsApi::SupplementalClaimSerializer.new(sc).serializable_hash
  end

  def validate
    render json: validation_success
  end

  def schema
    response = AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(
      AppealsApi::FormSchemas.new(
        SCHEMA_ERROR_TYPE,
        schema_version: 'v2'
      ).schema(self.class::FORM_NUMBER)
    )

    render json: response
  end

  def show
    id = params[:id]
    sc = AppealsApi::SupplementalClaim.select(ALLOWED_COLUMNS).find(id)
    sc = with_status_simulation(sc) if status_requested_and_allowed?

    render json: AppealsApi::SupplementalClaimSerializer.new(sc).serializable_hash
  rescue ActiveRecord::RecordNotFound
    render_supplemental_claim_not_found(id)
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

  def validation_success
    {
      data: {
        type: 'supplementalClaimValidation',
        attributes: {
          status: 'valid'
        }
      }
    }
  end

  def request_headers
    self.class::HEADERS.index_with { |key| request.headers[key] }.compact
  end

  def render_model_errors(model)
    render json: model_errors_to_json_api(model), status: MODEL_ERROR_STATUS
  end

  def render_supplemental_claim_not_found(id)
    render(
      status: :not_found,
      json: {
        errors: [
          {
            code: '404',
            detail: I18n.t('appeals_api.errors.not_found', type: 'SupplementalClaim', id: id),
            status: '404',
            title: 'Record not found'
          }
        ]
      }
    )
  end

  def render_errors(va_exception)
    case va_exception
    when JsonSchema::JsonApiMissingAttribute
      render json: va_exception.to_json_api, status: va_exception.code
    else
      if (notice_index = va_exception.errors.find_index do |e|
            e&.source&.fetch(:pointer, nil) == '/data/attributes/form5103Acknowledged'
          end)
        va_exception.errors[notice_index].detail = 'Please ensure the Veteran reviews the 38 U.S.CC 5103 information ' \
                                                   'regarding evidence necessary to substantiate the claim found here' \
                                                   ': https://www.va.gov/disability/how-to-file-claim/evidence-needed'
      end
      render json: { errors: va_exception.errors }, status: va_exception.status_code
    end
  end

  def evidence_submission_indicated?
    @json_body.dig('data', 'attributes', 'evidenceSubmission', 'evidenceType').include?('upload')
  end
end
