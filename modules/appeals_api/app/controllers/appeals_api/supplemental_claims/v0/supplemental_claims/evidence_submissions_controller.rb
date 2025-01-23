# frozen_string_literal: true

module AppealsApi::SupplementalClaims::V0::SupplementalClaims
  class EvidenceSubmissionsController < AppealsApi::ApplicationController
    include AppealsApi::CharacterUtilities
    include AppealsApi::IcnParameterValidation
    include AppealsApi::JsonFormatValidation
    include AppealsApi::OpenidAuth
    include AppealsApi::Schemas
    include AppealsApi::StatusSimulation
    include SentryLogging

    class EvidenceSubmissionRequestValidatorError < StandardError; end

    skip_before_action :authenticate
    before_action :validate_json_body, if: -> { request.post? }

    OAUTH_SCOPES = AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES
    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'supplemental_claims' }.freeze

    def show
      submission = AppealsApi::EvidenceSubmission.find_by(guid: params[:id])

      unless submission
        raise Common::Exceptions::ResourceNotFound.new(
          detail: I18n.t('appeals_api.errors.not_found', type: 'Evidence Submission', id: params[:id])
        )
      end

      validate_token_sc_access!(submission.supportable_id)

      submission = with_status_simulation(submission) if status_requested_and_allowed?

      render json: AppealsApi::EvidenceSubmissionSerializer.new(submission).serializable_hash
    end

    # rubocop:disable Metrics/MethodLength
    def create
      form_schemas.validate!('EVIDENCE_SUBMISSION', params.to_unsafe_h)

      validate_token_sc_access!(params[:scId])

      status, error = AppealsApi::EvidenceSubmissionRequestValidator.new(
        params[:scId], params[:ssn], 'SupplementalClaim'
      ).call

      unless status == :ok
        log_exception_to_sentry(EvidenceSubmissionRequestValidatorError.new(error), {}, {}, :warn)
        return render json: { errors: [error] }, status: error[:title].to_sym
      end

      upload = VBADocuments::UploadSubmission.create!(consumer_name: 'appeals_api_sc_evidence_submission')
      submission = AppealsApi::EvidenceSubmission.create!(
        {
          source: request.headers['X-Consumer-Username'],
          supportable_id: params[:scId],
          supportable_type: 'AppealsApi::SupplementalClaim',
          upload_submission: upload
        }
      )

      render status: :created,
             json: AppealsApi::EvidenceSubmissionSerializer.new(
               submission, { params: { render_location: true } }
             ).serializable_hash
    end
    # rubocop:enable Metrics/MethodLength

    private

    def validate_token_sc_access!(sc_id)
      validate_token_icn_access!(AppealsApi::SupplementalClaim.find(sc_id).veteran_icn)
    rescue ActiveRecord::RecordNotFound
      raise Common::Exceptions::ResourceNotFound.new(
        detail: I18n.t('appeals_api.errors.not_found', type: 'Supplemental Claim', id: sc_id)
      )
    end

    def token_validation_api_key
      Settings.modules_appeals_api.token_validation.supplemental_claims.api_key
    end
  end
end
