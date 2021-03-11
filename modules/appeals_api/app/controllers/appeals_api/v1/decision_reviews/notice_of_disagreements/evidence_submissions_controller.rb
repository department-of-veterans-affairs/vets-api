# frozen_string_literal: true

module AppealsApi::V1
  module DecisionReviews
    module NoticeOfDisagreements
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        skip_before_action :authenticate

        def show
          submissions = AppealsApi::EvidenceSubmission.where(
            supportable_id: params[:id],
            supportable_type: 'AppealsApi::NoticeOfDisagreement'
          )

          serialized = AppealsApi::EvidenceSubmissionSerializer.new(submissions)

          render json: serialized.serializable_hash
        end

        def create
          status, error = AppealsApi::FileValidator.new(params[:document]).call

          if status == :ok
            render json: { document: params[:document], uuid: params[:uuid] }
          else
            render json: { errors: [error] }, status: 422
          end
        end
      end
    end
  end
end
