# frozen_string_literal: true

class AppealSubmission < ApplicationRecord
  APPEAL_TYPES = %w[HLR NOD].freeze
  validates :user_uuid, :submitted_appeal_uuid, presence: true
  validates :type_of_appeal, inclusion: APPEAL_TYPES

  def self.submit_nod(request_body_hash:, current_user:)
    board_review_option = request_body_hash.dig('data', 'attributes', 'boardReviewOption')
    appeal_submission = new(type_of_appeal: 'NOD', user_uuid: current_user.uuid,
                            board_review_option: board_review_option)
    uploads_arr = request_body_hash.delete('nodUploads')
    nod_response_body = DecisionReview::Service.new
                                               .create_notice_of_disagreement(request_body: request_body_hash,
                                                                              user: current_user)
                                               .body
    appeal_submission.submitted_appeal_uuid = nod_response_body.dig('data', 'id')
    appeal_submission.save!

    uploads_arr.each do |upload_attrs|
      DecisionReview::SubmitUpload.perform_async(upload_attrs, appeal_submission.id)
    end
    nod_response_body
  end
end
