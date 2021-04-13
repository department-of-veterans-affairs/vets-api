# frozen_string_literal: true

module AppealsApi::V1
  module DecisionReviews
    module NoticeOfDisagreements
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        skip_before_action :authenticate
        before_action :set_notice_of_disagreement, only: :create
        before_action :set_veteran_identifier, only: :create
        before_action :set_submission_attributes, only: :create

        def create
          status, error = AppealsApi::RequestValidator.new(@notice_of_disagreement, @veteran_id).call

          if status == :ok
            upload = VBADocuments::UploadSubmission.create! consumer_name: 'appeals_api_nod_evidence_submission'
            submission = AppealsApi::EvidenceSubmission.create! @submission_attributes.merge(upload_submission: upload)

            render json: submission,
                   serializer: AppealsApi::EvidenceSubmissionSerializer,
                   key_transform: :camel_lower,
                   render_location: true
          else
            render json: { errors: [error] }, status: :unprocessable_entity
          end
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

        def set_notice_of_disagreement
          @nod_id ||= params[:nod_id]
          raise Common::Exceptions::ParameterMissing, 'nod_id' unless @nod_id

          @notice_of_disagreement ||= AppealsApi::NoticeOfDisagreement.find_by(id: @nod_id)
          raise Common::Exceptions::RecordNotFound, params[:nod_id] unless @notice_of_disagreement
        end

        def set_veteran_identifier
          @veteran_id ||= params[:headers]['X-VA-Veteran-SSN']
        end

        def set_submission_attributes
          @submission_attributes ||= {
            source: params['headers']['X-Consumer-Username'],
            supportable_id: params[:nod_id],
            supportable_type: 'AppealsApi::NoticeOfDisagreement'
          }
        end
      end
    end
  end
end
