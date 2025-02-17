# frozen_string_literal: true

module AppealsApi::V2
  module DecisionReviews
    module SupplementalClaims
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        include AppealsApi::StatusSimulation
        include SentryLogging
        include AppealsApi::CharacterUtilities
        include AppealsApi::Schemas
        include AppealsApi::GatewayOriginCheck

        class EvidenceSubmissionRequestValidatorError < StandardError; end

        SCHEMA_OPTIONS = { schema_version: 'v2', api_name: 'decision_reviews' }.freeze
        FORM_NUMBER = AppealsApi::V2::DecisionReviews::SupplementalClaimsController::FORM_NUMBER

        skip_before_action :authenticate
        before_action :supplemental_claim_uuid?, only: :create

        def show
          submission = AppealsApi::EvidenceSubmission.find_by(guid: params[:id])
          raise Common::Exceptions::RecordNotFound, params[:id] unless submission

          submission = with_status_simulation(submission) if status_requested_and_allowed?

          render json: AppealsApi::EvidenceSubmissionSerializer.new(
            submission, { params: { render_location: false } }
          ).serializable_hash
        end

        def create
          status, error = AppealsApi::EvidenceSubmissionRequestValidator.new(params[:sc_uuid],
                                                                             request.headers['X-VA-SSN'],
                                                                             'SupplementalClaim').call

          if status == :ok
            upload = VBADocuments::UploadSubmission.create! consumer_name: 'appeals_api_sc_evidence_submission'
            submission = AppealsApi::EvidenceSubmission.create! submission_attributes.merge(upload_submission: upload)

            render status: :accepted,
                   json: AppealsApi::EvidenceSubmissionSerializer.new(
                     submission, { params: { render_location: true } }
                   ).serializable_hash
          else
            log_error(error)
            render json: { errors: [error] }, status: error[:title].to_sym
          end
        end

        private

        def header_names = headers_schema['definitions']['scCreateParameters']['properties'].keys

        def supplemental_claim_uuid?
          uuid_missing_error unless params[:sc_uuid]
        end

        def uuid_missing_error
          error = {
            code: '400',
            detail: I18n.t('appeals_api.errors.missing_uuid', appeal_type: 'Supplemental Claim'),
            status: '400',
            title: 'bad_request'
          }
          log_error(error)

          render json: { errors: [error] }, status: :bad_request
        end

        def submission_attributes
          {
            source: request.headers['X-Consumer-Username'],
            supportable_id: params[:sc_uuid],
            supportable_type: 'AppealsApi::SupplementalClaim'
          }
        end

        def request_headers
          header_names.index_with { |key| request.headers[key] }.compact
        end

        def log_error(error_detail)
          log_exception_to_sentry(EvidenceSubmissionRequestValidatorError.new(error_detail), {}, {}, :warn)
          error_detail
        end
      end
    end
  end
end
