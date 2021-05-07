# frozen_string_literal: true

module AppealsApi::V1
  module DecisionReviews
    module NoticeOfDisagreements
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        include AppealsApi::StatusSimulation
        include SentryLogging

        class EvidenceSubmissionRequestValidatorError < StandardError; end

        skip_before_action :authenticate
        before_action :nod_id_present?, only: :create

        def create
          status, error = AppealsApi::EvidenceSubmissionRequestValidator.new(params[:nod_id],
                                                                             request.headers['X-VA-SSN']).call

          if status == :ok
            upload = VBADocuments::UploadSubmission.create! consumer_name: 'appeals_api_nod_evidence_submission'
            submission = AppealsApi::EvidenceSubmission.create! submission_attributes.merge(upload_submission: upload)

            render json: submission,
                   serializer: AppealsApi::EvidenceSubmissionSerializer,
                   key_transform: :camel_lower,
                   render_location: true
          else
            log_error(error)
            render json: { errors: [error] }, status: error[:title].to_sym
          end
        end

        def show
          submission = AppealsApi::EvidenceSubmission.find_by(guid: params[:id])
          raise Common::Exceptions::RecordNotFound, params[:id] unless submission

          submission = with_status_simulation(submission) if status_requested_and_allowed?

          render json: submission,
                 serializer: AppealsApi::EvidenceSubmissionSerializer,
                 key_transform: :camel_lower,
                 render_location: false
        end

        private

        def nod_id_present?
          nod_id_missing_error unless params[:nod_id]
        end

        def nod_id_missing_error
          error = { title: 'bad_request', detail: I18n.t('appeals_api.errors.missing_nod_id') }
          log_error(error)

          render json: { errors: [error] }, status: :bad_request
        end

        def submission_attributes
          {
            source: request.headers['X-Consumer-Username'],
            supportable_id: params[:nod_id],
            supportable_type: 'AppealsApi::NoticeOfDisagreement'
          }
        end

        def log_error(error_detail)
          log_exception_to_sentry(EvidenceSubmissionRequestValidatorError.new(error_detail), {}, {}, :warn)
          error_detail
        end
      end
    end
  end
end
