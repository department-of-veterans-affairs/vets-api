# frozen_string_literal: true

require 'appeals_api/form_schemas'

class AppealsApi::V2::DecisionReviews::SupplementalClaimsController < AppealsApi::ApplicationController
  include AppealsApi::JsonFormatValidation
  include AppealsApi::StatusSimulation
  include AppealsApi::CharacterUtilities
  include AppealsApi::MPIVeteran
  include AppealsApi::Schemas
  include AppealsApi::PdfDownloads
  include AppealsApi::GatewayOriginCheck

  skip_before_action :authenticate
  before_action :validate_icn_header, only: %i[index download]
  before_action :validate_json_format, if: -> { request.post? }
  before_action :validate_json_schema, only: %i[create validate]

  FORM_NUMBER = '200995'
  API_VERSION = 'V2'
  MODEL_ERROR_STATUS = 422
  SCHEMA_OPTIONS = { schema_version: 'v2', api_name: 'decision_reviews' }.freeze
  ALLOWED_COLUMNS = %i[id status code detail created_at updated_at].freeze
  ICN_HEADER = 'X-VA-ICN'
  ICN_REGEX = /^[0-9]{10}V[0-9]{6}$/

  def index
    veteran_scs = AppealsApi::SupplementalClaim.select(ALLOWED_COLUMNS)
                                               .where(veteran_icn: request_headers['X-VA-ICN'])
                                               .order(created_at: :desc)
    render json: AppealsApi::SupplementalClaimSerializer.new(veteran_scs).serializable_hash
  end

  def show
    id = params[:id]
    sc = AppealsApi::SupplementalClaim.select(ALLOWED_COLUMNS).find(id)
    sc = with_status_simulation(sc) if status_requested_and_allowed?

    render json: AppealsApi::SupplementalClaimSerializer.new(sc).serializable_hash
  rescue ActiveRecord::RecordNotFound
    render_supplemental_claim_not_found(id)
  end

  def create
    sc = AppealsApi::SupplementalClaim.new(
      auth_headers: request_headers,
      form_data: @json_body,
      source: request_headers['X-Consumer-Username'].presence&.strip,
      evidence_submission_indicated: evidence_submission_indicated?,
      api_version: self.class::API_VERSION,
      veteran_icn: request_headers['X-VA-ICN']
    )

    render_model_errors(sc) and return unless sc.validate

    sc.save

    if Flipper.enabled?(:decision_review_sc_form_v4_enabled)
      AppealsApi::PdfSubmitJob.perform_async(sc.id, 'AppealsApi::SupplementalClaim', 'v4')
    else
      AppealsApi::PdfSubmitJob.perform_async(sc.id, 'AppealsApi::SupplementalClaim', 'v3')
    end

    AppealsApi::AddIcnUpdater.perform_async(sc.id, 'AppealsApi::SupplementalClaim') if sc.veteran_icn.blank?

    render json: AppealsApi::SupplementalClaimSerializer.new(sc).serializable_hash
  end

  def validate
    render json: validation_success
  end

  def schema
    response = AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(form_schema)
    render json: response
  end

  def download
    sc = AppealsApi::SupplementalClaim.find(params[:id])
    icn = request_headers['X-VA-ICN']

    render_appeal_pdf_download(sc, "#{FORM_NUMBER}-supplemental-claim-#{params[:id]}.pdf", icn)
  rescue ActiveRecord::RecordNotFound
    render_supplemental_claim_not_found(params[:id])
  end

  private

  def header_names = headers_schema['definitions']['scCreateParameters']['properties'].keys

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
    header_names.index_with { |key| request.headers[key] }.compact
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
            detail: I18n.t('appeals_api.errors.not_found', type: 'SupplementalClaim', id:),
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
