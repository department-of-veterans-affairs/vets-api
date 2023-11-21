# frozen_string_literal: true

module AppealsApi::V2
  module DecisionReviews
    module NoticeOfDisagreements
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        include AppealsApi::StatusSimulation
        include SentryLogging
        include AppealsApi::CharacterUtilities
        include AppealsApi::Schemas

        SCHEMA_OPTIONS = { schema_version: 'v2', api_name: 'decision_reviews' }.freeze
        FORM_NUMBER = AppealsApi::V2::DecisionReviews::NoticeOfDisagreementsController::FORM_NUMBER

        class EvidenceSubmissionRequestValidatorError < StandardError; end

        skip_before_action :authenticate
        before_action :nod_uuid_present?, only: :create

        def create
          status, error = AppealsApi::EvidenceSubmissionRequestValidator.new(params[:nod_uuid],
                                                                             request.headers['X-VA-File-Number'],
                                                                             'NoticeOfDisagreement').call

          if status == :ok
            upload = VBADocuments::UploadSubmission.create! consumer_name: 'appeals_api_nod_evidence_submission'
            submission = AppealsApi::EvidenceSubmission.create! submission_attributes.merge(upload_submission: upload)

            render status: :accepted,
                   json: submission,
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

        def header_names = headers_schema['definitions']['nodCreateParameters']['properties'].keys

        def nod_uuid_present?
          nod_uuid_missing_error if params[:nod_uuid].blank?
        end

        def nod_uuid_missing_error
          error = {
            code: '400',
            detail: I18n.t('appeals_api.errors.missing_uuid', appeal_type: 'NOD'),
            status: '400',
            title: 'bad_request'
          }
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
          log_exception_to_sentry(EvidenceSubmissionRequestValidatorError.new(error_detail), {}, {}, :warn)
          error_detail
        end
      end
    end
  end
end
