# frozen_string_literal: true

module AppealsApi::V1
  module DecisionReviews
    module NoticeOfDisagreements
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        skip_before_action :authenticate
        before_action :set_submission_attributes, only: :create

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

        def set_submission_attributes
          @appeal ||= AppealsApi::NoticeOfDisagreement.find_by(id: params[:nod_id])
          raise Common::Exceptions::RecordNotFound, params[:nod_id] unless @appeal

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
