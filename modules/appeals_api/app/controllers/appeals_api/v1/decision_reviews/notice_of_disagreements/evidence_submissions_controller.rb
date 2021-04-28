# frozen_string_literal: true

module AppealsApi::V1
  module DecisionReviews
    module NoticeOfDisagreements
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        skip_before_action :authenticate
        before_action :nod_id_present?, only: :create
        before_action :set_notice_of_disagreement, only: :create
        before_action :validate_nod_attributes, only: :create
        before_action :set_submission_attributes, only: :create

        class InvalidReviewOption < StandardError
          def message
            I18n.t('appeals_api.errors.no_evidence_submission_accepted')
          end
        end

        class InvalidVeteranSSN < StandardError
          def message
            I18n.t('appeals_api.errors.invalid_submission_ssn')
          end
        end

        def create
          upload = VBADocuments::UploadSubmission.create! consumer_name: 'appeals_api_nod_evidence_submission'
          submission = AppealsApi::EvidenceSubmission.create! @submission_attributes.merge(upload_submission: upload)

          render json: submission,
                 serializer: AppealsApi::EvidenceSubmissionSerializer,
                 key_transform: :camel_lower,
                 render_location: true
        end

        def show
          submission = AppealsApi::EvidenceSubmission.find_by(guid: params[:id])
          raise Common::Exceptions::RecordNotFound, params[:id] unless submission

          render json: submission,
                 serializer: AppealsApi::EvidenceSubmissionSerializer,
                 key_transform: :camel_lower,
                 render_location: false
        end

        private

        def nod_id_present?
          raise Common::Exceptions::ParameterMissing, 'nod_id' unless params[:nod_id]
        end

        def set_notice_of_disagreement
          @notice_of_disagreement ||= AppealsApi::NoticeOfDisagreement.find_by(id: params[:nod_id])
          raise Common::Exceptions::RecordNotFound, params[:nod_id] unless @notice_of_disagreement
        end

        def validate_nod_attributes
          raise InvalidReviewOption unless @notice_of_disagreement.accepts_evidence?
          raise InvalidVeteranSSN unless ssn_match?
        end

        def ssn_match?
          return unless @notice_of_disagreement.auth_headers

          params['headers']['X-VA-SSN'] == @notice_of_disagreement.auth_headers['X-VA-SSN']
        end

        def set_submission_attributes
          @submission_attributes ||= {
            source: request.headers['X-Consumer-Username'],
            supportable_id: params[:nod_id],
            supportable_type: 'AppealsApi::NoticeOfDisagreement'
          }
        end
      end
    end
  end
end
