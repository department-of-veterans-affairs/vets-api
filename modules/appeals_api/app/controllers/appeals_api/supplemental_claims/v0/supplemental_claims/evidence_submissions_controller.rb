# frozen_string_literal: true

module AppealsApi::SupplementalClaims::V0::SupplementalClaims
  class EvidenceSubmissionsController < AppealsApi::ApplicationController
    include AppealsApi::CharacterUtilities
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
      raise Common::Exceptions::RecordNotFound, params[:id] unless submission

      submission = with_status_simulation(submission) if status_requested_and_allowed?

      render json: AppealsApi::SupplementalClaims::V0::EvidenceSubmissionSerializer.new(submission).serializable_hash
    end

    # rubocop:disable Metrics/MethodLength
    def create
      form_schemas.validate!('EVIDENCE_SUBMISSION', params.to_unsafe_h)

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
             json: AppealsApi::SupplementalClaims::V0::EvidenceSubmissionSerializer.new(
               submission, { params: { render_location: true } }
             ).serializable_hash
    end
    # rubocop:enable Metrics/MethodLength

    private

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :supplemental_claims, :api_key)
    end
  end
end
