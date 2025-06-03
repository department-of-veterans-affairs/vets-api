# frozen_string_literal: true

module AppealsApi::V1
  module DecisionReviews
    module NoticeOfDisagreements
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        include AppealsApi::StatusSimulation
        include AppealsApi::CharacterUtilities
        include AppealsApi::Schemas
        include AppealsApi::GatewayOriginCheck

        class EvidenceSubmissionRequestValidatorError < StandardError; end

        SCHEMA_OPTIONS = { schema_version: 'v1', api_name: 'decision_reviews' }.freeze
        FORM_NUMBER = AppealsApi::V1::DecisionReviews::NoticeOfDisagreementsController::FORM_NUMBER

        skip_before_action :authenticate
        before_action :nod_uuid_present?, only: :create

        def show
          submission = AppealsApi::EvidenceSubmission.find_by(guid: params[:id])
          raise Common::Exceptions::RecordNotFound, params[:id] unless submission

          submission = with_status_simulation(submission) if status_requested_and_allowed?

          render json: AppealsApi::EvidenceSubmissionSerializer.new(
            submission, { params: { render_location: false } }
          ).serializable_hash
        end

        def create
          status, error = AppealsApi::EvidenceSubmissionRequestValidator.new(params[:nod_uuid],
                                                                             request.headers['X-VA-SSN'],
                                                                             'NoticeOfDisagreement').call

          if status == :ok
            upload = VBADocuments::UploadSubmission.create! consumer_name: 'appeals_api_nod_evidence_submission'
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

        def header_names = headers_schema['definitions']['nodCreateHeadersRoot']['properties'].keys

        def nod_uuid_present?
          nod_uuid_missing_error unless params[:nod_uuid]
        end

        def nod_uuid_missing_error
          error = { title: 'bad_request', detail: I18n.t('appeals_api.errors.missing_uuid', appeal_type: 'NOD') }
          log_error(error)

          render json: { errors: [error] }, status: :bad_request
        end

        def submission_attributes
          {
            source: request.headers['X-Consumer-Username'],
            supportable_id: params[:nod_uuid],
            supportable_type: 'AppealsApi::NoticeOfDisagreement'
          }
        end

        def request_headers
          header_names.index_with { |key| request.headers[key] }.compact
        end

        def log_error(error_detail)
          req_validator_error = EvidenceSubmissionRequestValidatorError.new(error_detail)
          Rails.logger.warn("#{req_validator_error.message}.")
          Rails.logger.warn(req_validator_error.backtrace.join("\n")) unless req_validator_error.backtrace.nil?

          error_detail
        end
      end
    end
  end
end
