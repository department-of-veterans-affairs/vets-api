# frozen_string_literal: true

class AppealSubmission < ApplicationRecord
  self.ignored_columns = ['board_review_otpion']

  APPEAL_TYPES = %w[HLR NOD].freeze
  validates :user_uuid, :submitted_appeal_uuid, presence: true
  validates :type_of_appeal, inclusion: APPEAL_TYPES
  attr_encrypted :upload_metadata, key: Settings.db_encryption_key

  has_many :appeal_submission_uploads, dependent: :destroy

  def self.submit_nod(request_body_hash:, current_user:)
    form_data = request_body_hash.dig('data')
    appeal_submission = new(type_of_appeal: 'NOD', user_uuid: current_user.uuid,
                            board_review_option: form_data['attributes']['boardReviewOption'])

    uploads_arr = request_body_hash.delete('nodUploads')

    nod_response_body = DecisionReview::Service.new
                                               .create_notice_of_disagreement(request_body: request_body_hash,
                                                                              user: current_user)
                                               .body
    appeal_submission.submitted_appeal_uuid = nod_response_body.dig('data', 'id')
    appeal_submission.save!
    appeal_submission.enqueue_uploads(uploads_arr, current_user)
    nod_response_body
  end

  def enqueue_uploads(uploads_arr, user)
    self.upload_metadata = DecisionReview::Service.file_upload_metadata(user)
    save

    uploads_arr.each do |upload_attrs|
      binding.pry
      asu = AppealSubmissionUpload.create(decision_review_evidence_attachment_guid: upload_attrs['confirmationCode'],
                                          appeal_submission_id: id)
      DecisionReview::SubmitUpload.perform_async(asu.id)
    end
  end
end
