# frozen_string_literal: true

module AppealsApi::V1
  module DecisionReviews
    module NoticeOfDisagreements
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        skip_before_action :authenticate
        before_action :set_submission_attributes, if: -> { params[:nod_id] }

        def create
          submission = AppealsApi::EvidenceSubmission.create(@submission_attributes)
          signed_url = submission.get_location

          render json: { data:
                          {
                            attributes:
                              {
                                status: submission.status,
                                id: submission.id,
                                appeal_id: submission.supportable_id,
                                appeal_type: submission.supportable_type
                              },
                            location: signed_url
                          } }
        end

        def show
          submissions = AppealsApi::EvidenceSubmission.where(
            supportable_id: params[:id],
            supportable_type: 'AppealsApi::NoticeOfDisagreement'
          )

          serialized = AppealsApi::EvidenceSubmissionSerializer.new(submissions)

          render json: serialized.serializable_hash
        end

        private

        def set_submission_attributes
          @appeal ||= AppealsApi::NoticeOfDisagreement.find_by(id: params[:nod_id])
          raise Common::Exceptions::RecordNotFound, params[:nod_id] unless @appeal

          @submission_attributes ||= {
            supportable_id: params[:nod_id],
            supportable_type: 'NoticeOfDisagreement'
          }
        end
      end
    end
  end
end
