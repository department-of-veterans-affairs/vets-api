# frozen_string_literal: true

module AppealsApi::V1
  module DecisionReviews
    module NoticeOfDisagreements
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        skip_before_action :authenticate
        before_action :set_submission_attributes, only: :create

        def create
          submission = AppealsApi::EvidenceSubmission.create(@submission_attributes)

          render json: submission,
                 serializer: AppealsApi::EvidenceSubmissionSerializer,
                 key_transform: :camel_lower,
                 render_location: true
        end

        def show
          submissions = AppealsApi::EvidenceSubmission.where(
            supportable_id: params[:id],
            supportable_type: 'AppealsApi::NoticeOfDisagreement'
          )

          render json: submissions,
                 each_serializer: AppealsApi::EvidenceSubmissionSerializer,
                 key_transform: :camel_lower,
                 render_location: false
        end

        private

        def set_submission_attributes
          @appeal ||= AppealsApi::NoticeOfDisagreement.find_by(id: params[:nod_id])
          raise Common::Exceptions::RecordNotFound, params[:nod_id] unless @appeal

          @submission_attributes ||= {
            supportable_id: @appeal.id,
            supportable_type: @appeal.class
          }
        end
      end
    end
  end
end
