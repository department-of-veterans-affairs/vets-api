# frozen_string_literal: true

module AppealsApi::V1
  module DecisionReviews
    module NoticeOfDisagreements
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        def show
          submissions = AppealsApi::EvidenceSubmission.where(
            supportable_id: params[:id],
            supportable_type: 'AppealsApi::NoticeOfDisagremeent'
          )

          render json: submissions, serializer: AppealsApi::V1::EvidenceSubmissionSerializer
        end
      end
    end
  end
end
