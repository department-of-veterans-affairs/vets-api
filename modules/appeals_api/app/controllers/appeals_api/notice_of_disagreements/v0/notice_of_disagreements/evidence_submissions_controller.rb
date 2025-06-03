# frozen_string_literal: true

module AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreements
  class EvidenceSubmissionsController < AppealsApi::ApplicationController
    include AppealsApi::CharacterUtilities
    include AppealsApi::IcnParameterValidation
    include AppealsApi::JsonFormatValidation
    include AppealsApi::OpenidAuth
    include AppealsApi::Schemas
    include AppealsApi::StatusSimulation

    class EvidenceSubmissionRequestValidatorError < StandardError; end

    skip_before_action :authenticate
    before_action :validate_json_body, if: -> { request.post? }

    OAUTH_SCOPES = AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES
    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'notice_of_disagreements' }.freeze

    def show
      submission = AppealsApi::EvidenceSubmission.find_by(guid: params[:id])

      unless submission
        raise Common::Exceptions::ResourceNotFound.new(
          detail: I18n.t('appeals_api.errors.not_found', type: 'Evidence Submission', id: params[:id])
        )
      end

      validate_token_nod_access!(submission.supportable_id)

      submission = with_status_simulation(submission) if status_requested_and_allowed?

      render json: AppealsApi::EvidenceSubmissionSerializer.new(submission).serializable_hash
    end

    # rubocop:disable Metrics/MethodLength
    def create
      form_schemas.validate!('EVIDENCE_SUBMISSION', params.to_unsafe_h)

      validate_token_nod_access!(params[:nodId])

      status, error = AppealsApi::EvidenceSubmissionRequestValidator.new(
        params[:nodId], params[:fileNumber], 'NoticeOfDisagreement'
      ).call

      unless status == :ok
        req_validator_error = EvidenceSubmissionRequestValidatorError.new(error)
        Rails.logger.warn("#{req_validator_error.message}.")
        Rails.logger.warn(req_validator_error.backtrace.join("\n")) unless req_validator_error.backtrace.nil?

        return render json: { errors: [error] }, status: error[:title].to_sym
      end

      upload = VBADocuments::UploadSubmission.create! consumer_name: 'appeals_api_nod_evidence_submission'
      submission = AppealsApi::EvidenceSubmission.create!(
        {
          source: request.headers['X-Consumer-Username'],
          supportable_id: params[:nodId],
          supportable_type: 'AppealsApi::NoticeOfDisagreement',
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

    def validate_token_nod_access!(nod_id)
      validate_token_icn_access!(AppealsApi::NoticeOfDisagreement.find(nod_id).veteran_icn)
    rescue ActiveRecord::RecordNotFound
      raise Common::Exceptions::ResourceNotFound.new(
        detail: I18n.t('appeals_api.errors.not_found', type: 'Notice of Disagreement', id: nod_id)
      )
    end

    def token_validation_api_key
      Settings.modules_appeals_api.token_validation.notice_of_disagreements.api_key
    end
  end
end
