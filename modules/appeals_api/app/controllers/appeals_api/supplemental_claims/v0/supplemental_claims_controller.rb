# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::SupplementalClaims::V0
  class SupplementalClaimsController < AppealsApi::ApplicationController
    include AppealsApi::CharacterUtilities
    include AppealsApi::IcnParameterValidation
    include AppealsApi::JsonFormatValidation
    include AppealsApi::MPIVeteran
    include AppealsApi::OpenidAuth
    include AppealsApi::PdfDownloads
    include AppealsApi::Schemas
    include AppealsApi::StatusSimulation

    skip_before_action :authenticate
    before_action :validate_json_body, if: -> { request.post? }
    before_action :validate_json_schema, only: %i[create validate]
    before_action :validate_icn_parameter!, only: %i[index download]

    API_VERSION = 'V0'
    FORM_NUMBER = '200995'
    MODEL_ERROR_STATUS = 422
    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'supplemental_claims' }.freeze

    OAUTH_SCOPES = {
      GET: %w[veteran/SupplementalClaims.read representative/SupplementalClaims.read system/SupplementalClaims.read],
      PUT: %w[veteran/SupplementalClaims.write representative/SupplementalClaims.write system/SupplementalClaims.write],
      POST: %w[veteran/SupplementalClaims.write representative/SupplementalClaims.write system/SupplementalClaims.write]
    }.freeze

    # NOTE: index route is disabled until questions around claimant vs. veteran privacy are resolved
    def index
      veteran_scs = AppealsApi::SupplementalClaim.where(veteran_icn:).order(created_at: :desc)
      render_supplemental_claim(veteran_scs)
    end

    def schema
      response = AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(form_schema)
      render json: response
    end

    def show
      sc = AppealsApi::SupplementalClaim.find(params[:id])
      validate_token_icn_access!(sc.veteran_icn)

      sc = with_status_simulation(sc) if status_requested_and_allowed?

      render_supplemental_claim(sc)
    rescue ActiveRecord::RecordNotFound
      render_supplemental_claim_not_found(params[:id])
    end

    def validate
      render json: {
        data: {
          type: 'supplementalClaimValidation',
          attributes: {
            status: 'valid'
          }
        }
      }
    end

    def create
      submitted_icn = @json_body.dig('data', 'attributes', 'veteran', 'icn')
      validate_token_icn_access!(submitted_icn)

      sc = AppealsApi::SupplementalClaim.new(
        auth_headers: request_headers,
        form_data: @json_body,
        source: request_headers['X-Consumer-Username'].presence&.strip,
        evidence_submission_indicated: evidence_submission_indicated?,
        api_version: self.class::API_VERSION,
        veteran_icn: submitted_icn
      )

      return render_model_errors(sc) unless sc.validate

      sc.save
      AppealsApi::PdfSubmitJob.perform_async(sc.id, 'AppealsApi::SupplementalClaim', 'v3')
      render_supplemental_claim(sc, include_pii: true, status: :created)
    end

    def download
      render_appeal_pdf_download(
        AppealsApi::SupplementalClaim.find(params[:id]),
        "#{FORM_NUMBER}-supplemental-claim-#{params[:id]}.pdf",
        veteran_icn
      )
    rescue ActiveRecord::RecordNotFound
      render_supplemental_claim_not_found(params[:id])
    end

    private

    def evidence_submission_indicated?
      @json_body.dig('data', 'attributes', 'evidenceSubmission', 'evidenceType').include?('upload')
    end

    def validate_json_schema
      validate_headers(request_headers)
      validate_form_data(@json_body)
    rescue Common::Exceptions::DetailedSchemaErrors => e
      render json: { errors: e.errors }, status: :unprocessable_entity
    end

    def render_supplemental_claim(sc_or_scs, include_pii: false, **)
      serializer = include_pii ? SupplementalClaimSerializerWithPii : SupplementalClaimSerializer
      render(json: serializer.new(sc_or_scs).serializable_hash, **)
    end

    def render_supplemental_claim_not_found(id)
      raise Common::Exceptions::ResourceNotFound.new(
        detail: I18n.t('appeals_api.errors.not_found', type: 'Supplemental Claim', id:)
      )
    end

    def header_names = headers_schema['definitions']['scCreateParameters']['properties'].keys

    def request_headers
      header_names.index_with { |key| request.headers[key] }.compact
    end

    def render_model_errors(model)
      render json: model_errors_to_json_api(model), status: MODEL_ERROR_STATUS
    end

    def token_validation_api_key
      Settings.modules_appeals_api.token_validation.supplemental_claims.api_key
    end
  end
end
